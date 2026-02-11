//
//  PocketLedgerApp.swift
//  Pocket Ledger
//

import SwiftUI
import UserNotifications

extension Notification.Name {
    static let openTransactionTemplate = Notification.Name("openTransactionTemplate")
}

@main
struct PocketLedgerApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var transactionStore = TransactionStore()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled: Bool = false
    @AppStorage("selectedTheme") private var selectedTheme: Int = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false
    
    @State private var selectedTab: Int = 0
    @State private var showAddAccount = false
    @State private var showAddGroup = false
    @State private var showAddTransaction = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(
                    selectedTab: $selectedTab,
                    showAddAccount: $showAddAccount,
                    showAddGroup: $showAddGroup,
                    showAddTransaction: $showAddTransaction
                )
                .environmentObject(accountStore)
                .environmentObject(transactionStore)
                .preferredColorScheme(selectedTheme == 0 ? nil : (selectedTheme == 1 ? .light : .dark))
                
                if isLocked {
                    LockView(isLocked: $isLocked)
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            // Wire the two stores together BEFORE loading any data.
            // This ensures the very first loadTransactions call triggers a balance recompute.
            .task {
                transactionStore.accountStore = accountStore
                accountStore.transactionStore = transactionStore
                await accountStore.loadBookIndex(transactionStore: transactionStore)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    if isAppLockEnabled { isLocked = true }
                    // Bypass the debounce and flush any pending writes immediately.
                    accountStore.saveImmediately()
                    transactionStore.saveImmediately()
                }
            }
            .onAppear {
                if isAppLockEnabled { isLocked = true }
                appDelegate.transactionStore = transactionStore
            }
            
            // Show the User Manual on first launch only.
            // HelpView sets hasSeenOnboarding = true when the user taps "Get Started".
            .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
            )) {
            HelpView(isOnboarding: true)
            }
        }
        .commands {
            CommandMenu("Pocket Ledger") {
                Button("Go to Accounts") { selectedTab = 0 }
                    .keyboardShortcut("1", modifiers: [.command])
                
                Button("Go to Groups") { selectedTab = 1 }
                    .keyboardShortcut("2", modifiers: [.command])
                
                Button("Go to Transactions") { selectedTab = 2 }
                    .keyboardShortcut("3", modifiers: [.command])
                
                Divider()
                
                Button("Add Account") { showAddAccount = true }
                    .keyboardShortcut("A", modifiers: [.command])
                
                Button("Add Group") { showAddGroup = true }
                    .keyboardShortcut("G", modifiers: [.command])
                
                Button("Add Transaction") { showAddTransaction = true }
                    .keyboardShortcut("T", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    weak var transactionStore: TransactionStore?
    private var pendingTemplateID: String?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let templateID = userInfo["templateID"] as? String ?? response.notification.request.identifier
        
        if let store = transactionStore, !store.templates.isEmpty {
            postNotification(templateID: templateID)
        } else {
            pendingTemplateID = templateID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.processPendingNotification()
            }
        }
        
        completionHandler()
    }
    
    func processPendingNotification() {
        guard let templateID = pendingTemplateID else { return }
        
        if let store = transactionStore,
           store.templates.contains(where: { $0.id.uuidString == templateID }) {
            postNotification(templateID: templateID)
            pendingTemplateID = nil
        }
    }
    
    private func postNotification(templateID: String) {
        NotificationCenter.default.post(
            name: .openTransactionTemplate,
            object: nil,
            userInfo: ["id": templateID]
        )
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
