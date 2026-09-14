import SwiftUI

enum Constants {
    static let minTouchTarget: CGFloat = 44.0
    static let tileSize: CGFloat = 110.0
    static let tileSpacing: CGFloat = 10.0
    static let cornerRadius: CGFloat = 20.0
    static let sectionSpacing: CGFloat = 10.0
    static let maxFrameSize: Int = 16_777_216 // 16MB
    static let bonjourServiceType: String = "_windowed._tcp"
    static let keychainService: String = "com.windowed.pairing"
    
    enum Colors {
        // MARK: - Dark Forest Palette (#042008 Deep Evergreen Background)
        
        // Exact Deep Forest Green requested
        static let background = Color(red: 4/255, green: 32/255, blue: 8/255) // #042008
        static let secondaryBackground = Color(red: 8/255, green: 44/255, blue: 14/255) // #082C0E
        static let backgroundSubtle = Color(red: 14/255, green: 56/255, blue: 22/255) // #0E3816
        
        // MARK: - Refined Warm Champagne Gold Detail (Subtle, High Hierarchy)
        static let gold = Color(red: 0.84, green: 0.70, blue: 0.44) // #D6B370 Warm Muted Gold
        static let goldLight = Color(red: 0.94, green: 0.88, blue: 0.74) // #F0E0BD
        static let goldDark = Color(red: 0.65, green: 0.52, blue: 0.28) // #A68547
        static let goldGlow = Color(red: 0.84, green: 0.70, blue: 0.44).opacity(0.25)
        
        // MARK: - Surfaces & Cards (Pearl White / Crisp Surface Contrast on Dark Background)
        static let cardBackground = Color.white.opacity(0.97)
        static let cardBackgroundPure = Color.white
        static let cardBorder = Color(red: 0.85, green: 0.90, blue: 0.86)
        static let cardBorderGold = Color(red: 0.84, green: 0.70, blue: 0.44).opacity(0.5)
        
        static let tileBackground = Color.white
        static let tileSecondaryBackground = Color(red: 0.97, green: 0.99, blue: 0.97)
        static let tileShadow = Color.black.opacity(0.35)
        static let tileGlow = Color(red: 0.16, green: 0.60, blue: 0.38).opacity(0.20)
        static let pearlWhite = Color(red: 0.99, green: 0.99, blue: 0.99)
        
        // MARK: - Accents (Emerald Green & Status)
        static let accent = Color(red: 0.14, green: 0.56, blue: 0.36) // #248F5C
        static let accentHover = Color(red: 0.10, green: 0.46, blue: 0.28)
        static let pastelGreen = Color(red: 0.20, green: 0.65, blue: 0.42)
        static let pastelMint = Color(red: 0.14, green: 0.56, blue: 0.36)
        static let pastelSageLight = Color(red: 0.88, green: 0.95, blue: 0.90)
        static let connectedGreen = Color(red: 0.20, green: 0.72, blue: 0.45)
        
        // Status Colors
        static let searchingYellow = Color(red: 0.92, green: 0.74, blue: 0.25)
        static let disconnectedRed = Color(red: 0.90, green: 0.35, blue: 0.32)
        static let purple = Color(red: 0.58, green: 0.45, blue: 0.78)
        static let orange = Color(red: 0.92, green: 0.56, blue: 0.28)
        static let cyan = Color(red: 0.28, green: 0.65, blue: 0.75)
        
        // MARK: - Typography & AA Contrast
        // On White Cards: High-contrast deep evergreen charcoal (>15:1 ratio)
        static let textPrimary = Color(red: 0.06, green: 0.14, blue: 0.08) // #0F2414
        static let textSecondary = Color(red: 0.26, green: 0.38, blue: 0.30) // #42614D
        static let textTertiary = Color(red: 0.48, green: 0.60, blue: 0.52)
        
        // On Dark #042008 Background: Crisp light evergreen white (>14:1 ratio)
        static let textOnDark = Color(red: 0.94, green: 0.98, blue: 0.95)
        static let textSecondaryOnDark = Color(red: 0.72, green: 0.84, blue: 0.76)
        static let textTertiaryOnDark = Color(red: 0.52, green: 0.66, blue: 0.56)
    }
}
