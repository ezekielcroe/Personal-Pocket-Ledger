import SwiftUI
import LocalAuthentication

struct LockView: View {
    @Binding var isLocked: Bool
    @State private var errorText: String = ""
    
    // Add an environment check to ensure we only scan when active
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Pocket Ledger is Locked")
                .font(.title2)
                .fontWeight(.bold)
            
            if !errorText.isEmpty {
                Text(errorText)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Unlock") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea()
        // Use .task instead of .onAppear for better async handling
        .task {
            // Wait slightly for the app to finish the "opening" animation
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            authenticate()
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check if device supports FaceID/TouchID
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock your ledger"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // Success: Unlock
                        isLocked = false
                        errorText = ""
                    } else {
                        // Failure: Show specific error
                        if let err = authenticationError {
                            // If it was canceled by system, tell user to tap button
                            if let laError = err as? LAError, laError.code == .systemCancel {
                                errorText = "System interrupted Face ID. Tap Unlock to try again."
                            } else if let laError = err as? LAError, laError.code == .userCancel {
                                errorText = "Authentication canceled."
                            } else {
                                errorText = err.localizedDescription
                            }
                        } else {
                            errorText = "Authentication failed."
                        }
                    }
                }
            }
        } else {
            // Fallback for devices without FaceID or if permissions are missing
            errorText = "Biometrics not available. Please ensure Face ID is enabled for Pocket Ledger in iOS Settings."
        }
    }
}
