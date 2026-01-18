import SwiftUI

struct ContentView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("selectedTheme") private var selectedTheme: Int = 0
    
    // State to trigger the deep-link sheet (from Notifications)
    @State private var pendingTemplate: TransactionTemplate?

    var body: some View {
        TabView {
            // Tab 1: Accounts
            AccountsListView()
                .tabItem { Label("Accounts", systemImage: "wallet.pass") }

            // Tab 2: Transactions
            TransactionListView()
                .tabItem { Label("Transact", systemImage: "list.bullet") }

            // Tab 3: Templates (ADDED)
            TemplatesView()
                .tabItem { Label("Templates", systemImage: "doc.on.doc") }

            // Tab 4: Insights
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.pie") }

            // Tab 5: More (Settings)
            SettingsView()
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
        .preferredColorScheme(selectedTheme == 0 ? nil : (selectedTheme == 1 ? .light : .dark))
        
        // 1. Listen for the signal from AppDelegate (Notification Tap)
        .onReceive(NotificationCenter.default.publisher(for: .openTransactionTemplate)) { notification in
            if let idString = notification.userInfo?["id"] as? String,
               let uuid = UUID(uuidString: idString),
               let foundTemplate = data.templates.first(where: { $0.id == uuid }) {
                
                // Set this state to trigger the sheet below
                pendingTemplate = foundTemplate
            }
        }
        // 2. Present the Add View over EVERYTHING when a notification is tapped
        .sheet(item: $pendingTemplate) { template in
            AddTransactionView(initialType: template.type, template: template)
                .environmentObject(data)
        }
    }
}
