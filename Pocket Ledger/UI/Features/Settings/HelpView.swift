import SwiftUI

struct HelpView: View {
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. Introduction
                Section {
                    NavigationLink(destination: ManifestoView()) {
                        ManualRow(
                            icon: "sparkles",
                            color:.yellow,
                            title: "The Philosophy",
                            subtitle: "Active Guardianship & Mindful Spending"
                        )
                    }
                }
                
                // MARK: - 2. The Core System
                Section(header: Text("The System")) {
                    NavigationLink(destination: AccountsGuideView()) {
                        ManualRow(
                            icon: "building.columns.fill",
                            color:.blue,
                            title: "The Four Pillars",
                            subtitle: "Debit, Goal, Limit, and Debt."
                        )
                    }
                    
                    NavigationLink(destination: TaxonomyGuideView()) {
                        ManualRow(
                            icon: "tag.fill",
                            color:.orange,
                            title: "Taxonomy",
                            subtitle: "Orthogonal Metadata Strategy."
                        )
                    }
                    
                    NavigationLink(destination: ReconciliationGuideView()) {
                        ManualRow(
                            icon: "checkmark.seal.fill",
                            color:.green,
                            title: "Reconciliation",
                            subtitle: "The Traffic Light System & The Plug."
                        )
                    }
                }
                
                // MARK: - 3. Interaction & Workflow
                Section(header: Text("Interaction")) {
                    NavigationLink(destination: InterfaceGuideView()) {
                        ManualRow(
                            icon: "hand.tap.fill",
                            color:.purple,
                            title: "Interface Ergonomics",
                            subtitle: "Thumb-first design and gestures."
                        )
                    }
                    
                    NavigationLink(destination: PowerUserGuideView()) {
                        ManualRow(
                            icon: "keyboard.fill",
                            color:.primary,
                            title: "Power User Features",
                            subtitle: "Shortcuts & Deep Linking."
                        )
                    }
                }
                
                // MARK: - 4. Footer
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Pocket Ledger")
                               .font(.headline)
                            Text("Field Guide v1.0")
                               .font(.caption)
                               .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                   .listRowBackground(Color.clear)
                }
            }
           .navigationTitle("User Manual")
        }
    }
}

// MARK: - 1. Philosophy (Manifesto)
struct ManifestoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment:.leading, spacing: 20) {
                GroupBox {
                    VStack(alignment:.leading, spacing: 10) {
                        Label("Active Guardianship", systemImage: "hand.raised.fill")
                           .font(.headline)
                           .foregroundColor(.yellow)
                        
                        Text("Pocket Ledger is designed to encourage a more mindful and behavioural approach to your money.")
                           .font(.subheadline)
                        
                        Text("By manually entering every transaction, you feel the \"weight\" of your spending. This app is aimed to support you as you actively track and guard your money.")
                           .font(.subheadline)
                    }
                   .frame(maxWidth:.infinity, alignment:.leading)
                }
            }
           .padding()
        }
       .navigationTitle("Philosophy")
       .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 2. Four Pillars
struct AccountsGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Your accounts are not just buckets for money; they are behavioral contracts. Pocket Ledger divides the financial world into four distinct types of accounts, each with its own rules of engagement.")
                   .font(.subheadline)
                   .foregroundColor(.secondary)
            }
            
            Section(header: Text("🟢 Debit (The Liquid Hub)")) {
                GuideDetailRow(icon: "banknote", color:.green, title: "Concept", description: "\"Now\" Money.")
                GuideDetailRow(icon: "arrow.triangle.2.circlepath", color:.green, title: "Behavior", description: "Standard checking accounts or physical cash.")
                GuideDetailRow(icon: "checkmark.circle", color:.green, title: "Rule", description: "Use this for daily operational spending. Money flows in, money flows out.")
            }
            
            Section(header: Text("🔵 Goal (The Vault)")) {
                GuideDetailRow(icon: "target", color:.blue, title: "Concept", description: "\"Future\" Money.")
                GuideDetailRow(icon: "lock.fill", color:.blue, title: "The Lock Protocol", description: "You cannot spend directly from a Goal account. It is \"locked\" to prevent accidental leakage of your savings into daily life.")
                GuideDetailRow(icon: "key.fill", color:.blue, title: "Maturity Event", description: "Once your balance hits the Target Amount, the account triggers a \"Maturity\" option. You can then convert the account to Debit, unlocking the funds for the purchase.")
            }
            
            Section(header: Text("🟣 Limit (The Capacity Tank)")) {
                GuideDetailRow(icon: "envelope.fill", color:.purple, title: "Concept", description: "Credit as a Finite Resource.")
                GuideDetailRow(icon: "battery.100", color:.purple, title: "Behavior", description: "We show credit cards as Available Capacity. If you have a $2,000 limit, spending depletes the tank; paying the bill refills it.")
                GuideDetailRow(icon: "bolt.slash.fill", color:.purple, title: "The Circuit Breaker", description: "If you exceed your limit, you can freeze the account into a Debt account, preventing all further spending (outflows) until you pay down the balance.")
            }
            
            Section(header: Text("🟠 Debt (The Sink)")) {
                GuideDetailRow(icon: "exclamationmark.triangle.fill", color:.orange, title: "Concept", description: "The Liability to Destroy.")
                GuideDetailRow(icon: "arrow.down.to.line", color:.orange, title: "Rule", description: "You cannot spend from a Debt account. You can only transfer money INTO it. Every transfer is a victory, visually shrinking the negative balance.")
            }
        }
       .navigationTitle("Four Pillars")
    }
}

// MARK: - 3. Taxonomy
struct TaxonomyGuideView: View {
    var body: some View {
        List {
            Section(header: Text("The \"Orthogonal\" Strategy"), footer: Text("We separate the Where, the What, and the Why.")) {
                GuideDetailRow(icon: "building.columns.fill", color:.blue, title: "Account (Where)", description: "Where did the money come from? (e.g., \"Amex Gold\")")
                GuideDetailRow(icon: "folder.fill", color:.orange, title: "Category (What)", description: "What is the broad nature of the expense? (e.g., \"Sustenance\")")
                GuideDetailRow(icon: "tag.fill", color:.purple, title: "Tag (Why/Who)", description: "What was the specific context? (e.g., \"#DateNight\")")
            }
            
            Section(footer: Text("Keep Categories broad (Housing, Transport, Food) and use Tags for specifics. This keeps your charts readable.")) {
                Text("Pro Tip")
                   .font(.headline)
                   .foregroundColor(.blue)
            }
            
            Section(header: Text("Smart Tags & Keywords")) {
                VStack(alignment:.leading, spacing: 8) {
                    Text("Don't create a category for every coffee shop. Instead, create a single tag called #Caffeine.")
                    Divider()
                    HStack(alignment:.top) {
                        Image(systemName: "gearshape.fill").foregroundColor(.gray)
                        Text("How it works: In the Tag settings, add keywords like \"Starbucks,\" \"Dunkin,\" and \"Nespresso\" to the #Caffeine tag.")
                           .font(.caption).foregroundColor(.secondary)
                    }
                    HStack(alignment:.top) {
                        Image(systemName: "sparkles").foregroundColor(.yellow)
                        Text("The Magic: When you search for \"Starbucks\" later, the app automatically finds all #Caffeine transactions.")
                           .font(.caption).foregroundColor(.secondary)
                    }
                }
               .padding(.vertical, 4)
            }
        }
       .navigationTitle("Taxonomy")
    }
}

// MARK: - 4. Reconciliation
struct ReconciliationGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Since Pocket Ledger is offline-first, it relies on you to tell the truth. Reconciliation is the act of verifying that the App's truth matches Reality (your bank balance).")
                   .font(.subheadline)
                   .foregroundColor(.secondary)
            }
            
            Section(header: Text("The Traffic Light System")) {
                HStack {
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                    Text("Green").bold()
                    Spacer()
                    Text("Verified < 7 days ago. Trusted.")
                       .font(.caption).foregroundColor(.secondary)
                }
                HStack {
                    Circle().fill(Color.yellow).frame(width: 12, height: 12)
                    Text("Yellow").bold()
                    Spacer()
                    Text("Verified < 30 days ago. Caution.")
                       .font(.caption).foregroundColor(.secondary)
                }
                HStack {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    Text("Red").bold()
                    Spacer()
                    Text("Verified > 30 days ago. Stale.")
                       .font(.caption).foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("The Plug Feature")) {
                VStack(alignment:.leading, spacing: 10) {
                    Text("If your app says you have $500 but your bank says $498.50, don't waste hours hunting for the $1.50.")
                    
                    Label("Use the Reconcile tool", systemImage: "wrench.and.screwdriver.fill")
                       .font(.headline)
                    
                    Text("Input the actual balance ($498.50). The app will calculate the difference and automatically generate a \"Reconciliation Adjustment\" transaction to plug the gap.")
                       .font(.caption)
                    
                    Text("Perfection is the enemy of consistency.")
                       .font(.caption)
                       .italic()
                       .foregroundColor(.secondary)
                }
               .padding(.vertical, 4)
            }
        }
       .navigationTitle("Reconciliation")
    }
}

// MARK: - 5. Interface
struct InterfaceGuideView: View {
    var body: some View {
        List {
            Section {
                Text("We designed the interface for how you actually hold your phone—with one hand, using your thumb.")
                   .font(.subheadline)
                   .foregroundColor(.secondary)
            }
            
            Section(header: Text("Ergonomics")) {
                GuideDetailRow(icon: "arrow.down.to.line", color:.blue, title: "Bottom-Heavy Controls", description: "The \"Save\" and \"Add\" buttons live at the bottom of the screen, right above the keyboard. You never have to reach for the top corners.")
            }
            
            Section(header: Text("The Math Engine")) {
                VStack(alignment:.leading, spacing: 8) {
                    Label("Every amount field is a calculator.", systemImage: "function")
                       .font(.headline)
                    
                    Text("Scenario: You paid for dinner ($45.00) but split it with a friend.")
                       .font(.caption)
                    
                    HStack {
                        Text("Action:")
                           .font(.caption).bold()
                        Text("Type 45.00 / 2 directly into the field.")
                           .font(.caption).monospaced()
                    }
                    
                    Text("The app calculates $22.50 instantly. You can also chain operators like 12 + 5.50 + 3.")
                       .font(.caption)
                       .foregroundColor(.secondary)
                }
               .padding(.vertical, 4)
            }
            
            Section(header: Text("Swipe Gestures")) {
                SwipeGuideRow(direction: "Right", color:.blue, action: "Edit", icon: "pencil")
                SwipeGuideRow(direction: "Left", color:.red, action: "Delete", icon: "trash.fill")
                SwipeGuideRow(direction: "Left", color:.orange, action: "Archive", icon: "archivebox.fill")
            }
        }
       .navigationTitle("Interface")
    }
}

// MARK: - 6. Power User
struct PowerUserGuideView: View {
    var body: some View {
        List {
            Section(header: Text("Keyboard Shortcuts (iPad / Mac)"), footer: Text("Pocket Ledger supports full navigation without touching the screen.")) {
                HotkeyDisplayRow(keys: ["⌘", "1-4"], action: "Switch Tabs")
                HotkeyDisplayRow(keys: ["⌘", "T"], action: "New Transaction")
                HotkeyDisplayRow(keys: ["⌘", "A"], action: "New Account")
                HotkeyDisplayRow(keys: ["⌘", "G"], action: "New Account Group")
            }
            
            Section(header: Text("Notification Deep Linking")) {
                VStack(alignment:.leading, spacing: 12) {
                    Text("Pocket Ledger allows users to create templates (with scheduled reminders) to log a recurring bill.")
                       .font(.caption)
                       .foregroundColor(.secondary)
                    
                    HStack(alignment:.top) {
                        Image(systemName: "1.circle.fill").foregroundColor(.gray)
                        Text("Create a Template: Go to the Templates tab and create a transaction for \"Rent.\"")
                           .font(.caption)
                    }
                    HStack(alignment:.top) {
                        Image(systemName: "2.circle.fill").foregroundColor(.gray)
                        Text("Add a Schedule: Set it to remind you \"Monthly on the 1st.\"")
                           .font(.caption)
                    }
                    HStack(alignment:.top) {
                        Image(systemName: "3.circle.fill").foregroundColor(.blue)
                        Text("The Deep Link: When the notification arrives, long-press or tap it. The app launches directly into the pre-filled form. Just tap Save.")
                           .font(.caption)
                    }
                }
               .padding(.vertical, 4)
            }
        }
       .navigationTitle("Power User")
    }
}

// MARK: - Reusable Components

struct ManualRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
               .font(.title2)
               .foregroundColor(color)
               .frame(width: 32)
            
            VStack(alignment:.leading, spacing: 2) {
                Text(title)
                   .font(.headline)
                Text(subtitle)
                   .font(.caption)
                   .foregroundColor(.secondary)
            }
        }
       .padding(.vertical, 4)
    }
}

struct GuideDetailRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment:.top, spacing: 12) {
            Image(systemName: icon)
               .foregroundColor(color)
               .frame(width: 24)
            
            VStack(alignment:.leading, spacing: 4) {
                Text(title).bold()
                Text(description)
                   .font(.caption)
                   .foregroundColor(.secondary)
                   .fixedSize(horizontal: false, vertical: true)
            }
        }
       .padding(.vertical, 4)
    }
}

struct HotkeyDisplayRow: View {
    let keys: [String]
    let action: String
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                       .font(.system(.caption, design:.monospaced))
                       .fontWeight(.bold)
                       .foregroundColor(.primary)
                       .padding(.horizontal, 6)
                       .padding(.vertical, 4)
                       .background(Color.secondary.opacity(0.2))
                       .cornerRadius(4)
                }
            }
            Spacer()
            Text(action)
               .font(.subheadline)
               .foregroundColor(.secondary)
        }
    }
}

struct SwipeGuideRow: View {
    let direction: String
    let color: Color
    let action: String
    let icon: String
    
    var body: some View {
        HStack {
            Text("Swipe \(direction)")
               .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(action)
            }
           .font(.caption)
           .fontWeight(.bold)
           .foregroundColor(.white)
           .padding(.horizontal, 8)
           .padding(.vertical, 4)
           .background(color)
           .cornerRadius(4)
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
