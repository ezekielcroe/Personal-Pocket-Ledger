import SwiftUI

struct ContentView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("selectedTheme") private var selectedTheme: Int = 0
    @AppStorage("defaultTab") private var defaultTab: Int = 0
    
    // MARK: - Navigation State (Bound to BudgetApp)
    // We changed these from @State to @Binding so BudgetApp can control them
    @Binding var selectedTab: Int
    @Binding var showAddAccount: Bool
    @Binding var showAddGroup: Bool
    @Binding var showAddTransaction: Bool
    
    // Deep Link State (Internal)
    @State private var pendingTemplate: TransactionTemplate?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Accounts
            AccountsListView(
                globalAddAccountTrigger: $showAddAccount,
                globalAddGroupTrigger: $showAddGroup
            )
            .tabItem { Label("Accounts", systemImage: "building.columns") }
            .tag(0)
            
            // Tab 2: Transactions
            TransactionListView(
                globalAddTransactionTrigger: $showAddTransaction
            )
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
            
            // Tab 5: More
            SettingsView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .preferredColorScheme(selectedTheme == 0 ? nil : (selectedTheme == 1 ? .light : .dark))
        .onAppear {
            // Sync with default tab setting on launch
            // We only set this if we are at the default 0 state
            if selectedTab == 0 {
                selectedTab = defaultTab
            }
        }
        
        // MARK: - Notification Handling
        .onReceive(NotificationCenter.default.publisher(for: .openTransactionTemplate)) { notification in
            if let idString = notification.userInfo?["id"] as? String,
               let uuid = UUID(uuidString: idString),
               let foundTemplate = data.templates.first(where: { $0.id == uuid }) {
                pendingTemplate = foundTemplate
            }
        }
        .sheet(item: $pendingTemplate) { template in
            AddTransactionView(initialType: template.type, template: template)
                .environmentObject(data)
        }
    }
}
