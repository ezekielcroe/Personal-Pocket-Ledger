import SwiftUI
import LocalAuthentication

struct LockView: View {
    @Binding var isLocked: Bool
    @State private var errorText: String = ""
    @State private var isAuthenticating = false

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
            .disabled(isAuthenticating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea()
        .onAppear {
            // Small delay so the lock screen finishes animating in
            // before the Face ID sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                authenticate()
            }
        }
    }

    private func authenticate() {
        // Prevent overlapping authentication attempts
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorText = ""

        let context = LAContext()
        var error: NSError?

        // .deviceOwnerAuthentication allows passcode as fallback
        // if biometrics fail or are unavailable
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorText = "Authentication not available. Please ensure Face ID or a passcode is set up in iOS Settings."
            isAuthenticating = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock your ledger"
        ) { success, authenticationError in
            DispatchQueue.main.async {
                isAuthenticating = false

                if success {
                    isLocked = false
                    errorText = ""
                } else if let error = authenticationError as? LAError {
                    switch error.code {
                    case .systemCancel:
                        // System dismissed Face ID (e.g. incoming call)
                        // Don't show an error — user can tap Unlock to retry
                        break
                    case .userCancel:
                        // User tapped Cancel — don't show an error
                        break
                    case .biometryNotEnrolled:
                        errorText = "Face ID is not set up. Please enable it in iOS Settings."
                    case .biometryLockout:
                        errorText = "Face ID is locked. Enter your passcode to unlock."
                    default:
                        errorText = error.localizedDescription
                    }
                }
            }
        }
    }
}
