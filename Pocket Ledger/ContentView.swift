import SwiftUI

struct ContentView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("selectedTheme") private var selectedTheme: Int = 0
    @AppStorage("defaultTab") private var defaultTab: Int = 0  // NEW
    
    // State to trigger the deep-link sheet (from Notifications)
    @State private var pendingTemplate: TransactionTemplate?
    
    // NEW: Track selected tab
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Accounts
            AccountsListView()
                .tabItem { Label("Accounts", systemImage: "books.vertical.fill") }
                .tag(0)
            
            // Tab 2: Transactions
            TransactionListView()
                .tabItem { Label("Transact", systemImage: "arrow.left.arrow.right") }
                .tag(1)
            
            // Tab 3: Templates
            TemplatesView()
                .tabItem { Label("Templates", systemImage: "doc.on.doc.fill") }
                .tag(2)
            
            // Tab 4: Insights
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.pie.fill") }
                .tag(3)
            
            // Tab 5: More (Settings)
            SettingsView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .preferredColorScheme(selectedTheme == 0 ? nil : (selectedTheme == 1 ? .light : .dark))
        .onAppear {
            // NEW: Set default tab on first appearance
            selectedTab = defaultTab
        }
        
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
