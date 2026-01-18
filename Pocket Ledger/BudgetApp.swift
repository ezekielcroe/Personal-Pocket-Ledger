import SwiftUI
import UserNotifications

// 1. Define a custom notification name
extension Notification.Name {
    static let openTransactionTemplate = Notification.Name("openTransactionTemplate")
}

@main
struct BudgetApp: App {
    @StateObject private var data = AppData()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Settings
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled: Bool = false
    @AppStorage("selectedTheme") private var selectedTheme: Int = 0
    
    // Lifecycle
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(data)
                    .preferredColorScheme(selectedTheme == 0 ? nil : (selectedTheme == 1 ? .light : .dark))
                
                if isLocked {
                    LockView(isLocked: $isLocked)
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .inactive || newPhase == .background {
                    if isAppLockEnabled { isLocked = true }
                }
            }
            .onAppear {
                if isAppLockEnabled { isLocked = true }
            }
        }
    }
}

// 2. Update Delegate to handle notification taps
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set the delegate so we can capture taps
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        return true
    }

    // This function runs when a user taps a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // The Identifier matches the Template UUID string we set in AppData
        let templateID = response.notification.request.identifier
        
        // Broadcast this ID to the SwiftUI views
        NotificationCenter.default.post(
            name: .openTransactionTemplate,
            object: nil,
            userInfo: ["id": templateID]
        )
        
        completionHandler()
    }
    
    // Optional: Allow notifications to show even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
