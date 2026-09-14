import UIKit
import Foundation
import os

private let logger = Logger(subsystem: "com.windowed", category: "FaviconService")

public actor FaviconService {
    public static let shared = FaviconService()
    
    private var memoryCache: [String: (base64: String, image: UIImage)] = [:]
    private let urlSession: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 8.0
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Returns the cached favicon if available in memory or on disk.
    public func cachedFavicon(for urlString: String) async -> (base64: String?, image: UIImage?) {
        guard let domain = Self.extractDomain(from: urlString) else { return (nil, nil) }
        
        // 1. Check memory cache
        if let cached = memoryCache[domain] {
            return (cached.base64, cached.image)
        }
        
        // 2. Check disk cache via IconCache
        let cacheKey = "favicon_\(domain)"
        if let diskImage = await IconCache.shared.image(for: cacheKey) {
            if let pngData = diskImage.pngData() {
                let base64 = pngData.base64EncodedString()
                memoryCache[domain] = (base64, diskImage)
                return (base64, diskImage)
            }
        }
        
        return (nil, nil)
    }
    
    /// Fetches the favicon for the given URL string, trying multiple resolution strategies.
    public func fetchFavicon(for urlString: String) async -> (base64: String?, image: UIImage?) {
        guard let domain = Self.extractDomain(from: urlString) else { return (nil, nil) }
        
        // Return existing cached version immediately
        let (cachedBase64, cachedImg) = await cachedFavicon(for: urlString)
        if let cachedBase64 = cachedBase64, let cachedImg = cachedImg {
            return (cachedBase64, cachedImg)
        }
        
        // Resolution strategies in priority order
        let candidateURLs = [
            // Strategy 1: Google S2 Favicon API (high-res 128px PNG)
            URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128"),
            // Strategy 2: DuckDuckGo Icons API
            URL(string: "https://icons.duckduckgo.com/ip3/\(domain).ico"),
            // Strategy 3: Standard direct favicon.ico
            URL(string: "https://\(domain)/favicon.ico"),
            // Strategy 4: Fallback with http if https direct fails
            URL(string: "http://\(domain)/favicon.ico")
        ].compactMap { $0 }
        
        for candidateURL in candidateURLs {
            if let (base64, image) = await downloadAndProcessIcon(from: candidateURL, domain: domain) {
                return (base64, image)
            }
        }
        
        // Strategy 5: Parse HTML <link rel="icon"> or <link rel="apple-touch-icon">
        if let htmlIconURL = await extractFaviconURLFromHTML(domain: domain) {
            if let (base64, image) = await downloadAndProcessIcon(from: htmlIconURL, domain: domain) {
                return (base64, image)
            }
        }
        
        return (nil, nil)
    }
    
    // MARK: - Helpers
    
    private func downloadAndProcessIcon(from url: URL, domain: String) async -> (base64: String, image: UIImage)? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  data.count > 64 else {
                return nil
            }
            
            guard let uiImage = UIImage(data: data),
                  uiImage.size.width > 0,
                  uiImage.size.height > 0 else {
                return nil
            }
            
            // Prefer PNG representation for crisp transparency
            guard let pngData = uiImage.pngData() ?? uiImage.jpegData(compressionQuality: 0.9) else {
                return nil
            }
            
            let base64 = pngData.base64EncodedString()
            
            // Save to memory and disk cache
            memoryCache[domain] = (base64, uiImage)
            let cacheKey = "favicon_\(domain)"
            await IconCache.shared.store(pngData, for: cacheKey, hash: "v1")
            
            logger.debug("Successfully resolved and cached favicon for \(domain)")
            return (base64, uiImage)
        } catch {
            return nil
        }
    }
    
    private func extractFaviconURLFromHTML(domain: String) async -> URL? {
        guard let pageURL = URL(string: "https://\(domain)") else { return nil }
        
        do {
            var request = URLRequest(url: pageURL)
            request.timeoutInterval = 4.0
            
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            // Read first 32KB of HTML
            let prefixData = data.prefix(32768)
            guard let html = String(data: prefixData, encoding: .utf8) ?? String(data: prefixData, encoding: .ascii) else {
                return nil
            }
            
            // Look for <link ... rel="apple-touch-icon" ... href="..." > or rel="icon"
            let patterns = [
                #"<link[^>]+rel=["'](?:apple-touch-icon(?:-precomposed)?|shortcut icon|icon)["'][^>]+href=["']([^"']+)["']"#,
                #"<link[^>]+href=["']([^"']+)["'][^>]+rel=["'](?:apple-touch-icon(?:-precomposed)?|shortcut icon|icon)["']"#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)) {
                    if let hrefRange = Range(match.range(at: 1), in: html) {
                        let href = String(html[hrefRange])
                        if let resolved = URL(string: href, relativeTo: pageURL) {
                            return resolved.absoluteURL
                        }
                    }
                }
            }
        } catch {
            // Silently ignore HTML parse failures
        }
        
        return nil
    }
    
    // MARK: - Domain Normalization
    
    /// Extracts a clean domain string (e.g. "github.com") from any URL string.
    public static func extractDomain(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        var candidate = trimmed
        if !candidate.contains("://") {
            candidate = "https://" + candidate
        }
        
        guard let url = URL(string: candidate),
              let host = url.host(),
              !host.isEmpty else {
            return nil
        }
        
        var clean = host.lowercased()
        if clean.hasPrefix("www.") {
            clean = String(clean.dropFirst(4))
        }
        return clean
    }
}
