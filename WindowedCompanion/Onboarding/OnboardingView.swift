import SwiftUI

public struct OnboardingView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    @State private var currentStep = 0
    @State private var selectedLaunchAtLogin: Bool? = nil
    
    public var onFinish: () -> Void
    
    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Step Indicators
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Capsule()
                        .fill(step == currentStep ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: step == currentStep ? 28 : 10, height: 6)
                        .animation(.spring(), value: currentStep)
                }
            }
            .padding(.top, 16)
            
            Spacer()
            
            // Step Content
            switch currentStep {
            case 0:
                welcomeAndPermissionsView
            case 1:
                launchConsentView
            case 2:
                pairingStepView
            default:
                EmptyView()
            }
            
            Spacer()
            
            // Navigation Buttons
            HStack {
                if currentStep > 0 {
                    Button("Atrás") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                }
                
                Spacer()
                
                if currentStep == 0 {
                    Button("Continuar") {
                        withAnimation {
                            currentStep = 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else if currentStep == 1 {
                    Button("Continuar") {
                        if let choice = selectedLaunchAtLogin {
                            settingsManager.recordLaunchConsent(accepted: choice)
                        } else {
                            settingsManager.recordLaunchConsent(accepted: false)
                        }
                        withAnimation {
                            currentStep = 2
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedLaunchAtLogin == nil)
                } else {
                    Button("Listo") {
                        onFinish()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 580, height: 480)
    }
    
    // MARK: - Step 0: Welcome & Permissions
    
    private var welcomeAndPermissionsView: some View {
        VStack(spacing: 18) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
            
            VStack(spacing: 6) {
                Text("Bienvenido a Windowed Companion")
                    .font(.title.bold())
                
                Text("Para que tu iPhone pueda controlar ventanas, multimedia y apps, Windowed necesita permisos de Accesibilidad.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: permissionManager.hasAccessibility ? "checkmark.circle.fill" : "hand.raised.fill")
                        .foregroundStyle(permissionManager.hasAccessibility ? .green : .orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accesibilidad")
                            .font(.headline)
                        Text("Requerido para enfocar y mover ventanas en tu pantalla")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !permissionManager.hasAccessibility {
                        Button("Conceder Permiso") {
                            permissionManager.requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Concedido")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Step 1: Launch at Login Explicit Consent
    
    private var launchConsentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("¿Iniciar automáticamente con tu Mac?")
                    .font(.title2.bold())
                
                Text("Windowed puede iniciarse en segundo plano al encender tu Mac para que puedas controlarlo desde tu iPhone en cualquier momento sin abrir la app manualmente.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    selectedLaunchAtLogin = true
                }) {
                    HStack {
                        Image(systemName: selectedLaunchAtLogin == true ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedLaunchAtLogin == true ? .blue : .secondary)
                        Text("Sí, iniciar Windowed automáticamente")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(14)
                    .background(selectedLaunchAtLogin == true ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    selectedLaunchAtLogin = false
                }) {
                    HStack {
                        Image(systemName: selectedLaunchAtLogin == false ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedLaunchAtLogin == false ? .blue : .secondary)
                        Text("No, iniciaré la app manualmente cuando la necesite")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(14)
                    .background(selectedLaunchAtLogin == false ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Step 2: Pairing Code
    
    private var pairingStepView: some View {
        PairingDisplayView()
    }
}
