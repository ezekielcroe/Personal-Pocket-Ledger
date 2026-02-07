import SwiftUI

struct HelpView: View {
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. Introduction (The Why)
                Section {
                    NavigationLink(destination: ManifestoView()) {
                        ManualRow(
                            icon: "sparkles",
                            color: .yellow,
                            title: "The Philosophy",
                            subtitle: "Why this app is difficult by design."
                        )
                    }
                }
                
                // MARK: - 2. The System (The What)
                Section(header: Text("The System")) {
                    NavigationLink(destination: AccountsGuideView()) {
                        ManualRow(
                            icon: "building.columns.fill",
                            color: .blue,
                            title: "Account Doctrines",
                            subtitle: "Debit, Goal, Budget, and Debt."
                        )
                    }
                    
                    NavigationLink(destination: TaxonomyGuideView()) {
                        ManualRow(
                            icon: "tag.fill",
                            color: .orange,
                            title: "Taxonomy",
                            subtitle: "Categories, Tags, and Keywords."
                        )
                    }
                }
                
                // MARK: - 3. The Workflow (The How)
                Section(header: Text("The Workflow")) {
                    NavigationLink(destination: TemplatesGuideView()) {
                        ManualRow(
                            icon: "doc.on.doc.fill",
                            color: .purple,
                            title: "Templates & Automation",
                            subtitle: "Recurring bills and reminders."
                        )
                    }
                    
                    NavigationLink(destination: PowerUserGuideView()) {
                        ManualRow(
                            icon: "keyboard.fill",
                            color: .primary,
                            title: "Power User Guide",
                            subtitle: "Hotkeys, Math Engine, and Gestures."
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
                            Text("v1.0 • Local Storage Only")
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

// MARK: - Sub-Views (The Pages)

struct ManifestoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Active Guardianship", systemImage: "hand.raised.fill")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        Text("We reject 'Passive Observation'. Financial clarity comes from the act of recording, not just viewing. By manually entering transactions, you feel the weight of every dollar.")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Digital Sovereignty", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("Your data lives on this device. No servers, no bank syncing, no tracking. You are the sole owner of your financial history.")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Friction is a Feature", systemImage: "bolt.horizontal.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("Automation breeds complacency. Friction breeds awareness. We intentionally require you to confirm every action.")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Philosophy")
        .background(Color(.systemGroupedBackground))
    }
}

struct AccountsGuideView: View {
    var body: some View {
        List {
            Section(header: Text("The Four Types")) {
                GuideDetailRow(icon: "banknote", color: .green, title: "Debit", description: "Standard liquid cash (Checking, Wallet).")
                GuideDetailRow(icon: "target", color: .blue, title: "Goal", description: "Savings container. Set a target amount to track progress.")
                GuideDetailRow(icon: "envelope.fill", color: .purple, title: "Budget (Credit)", description: "Treats Credit Limits as 'Budgets'. Spending depletes your available capacity.")
                GuideDetailRow(icon: "lock.fill", color: .orange, title: "Debt", description: "A 'Sink' account. You cannot spend from here. You can only transfer IN to pay it off.")
            }
        }
        .navigationTitle("Accounts")
    }
}

struct TaxonomyGuideView: View {
    var body: some View {
        List {
            Section(header: Text("Organization Strategy")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Categories are Broad")
                        .font(.headline)
                    Text("Use high-level buckets like 'Sustenance' or 'Housing'. Avoid micro-categories.")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags are Specific")
                        .font(.headline)
                    Text("Use tags for context like '#Vacation' or '#DateNight'.")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keywords are Magic")
                        .font(.headline)
                    Text("Don't create a tag for every vendor. Add 'Starbucks' as a keyword to the '#Coffee' tag. Searching for 'Starbucks' will auto-apply the tag.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Taxonomy")
    }
}

struct TemplatesGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Templates serve two purposes: Speed and Reminders.")
            }
            
            Section(header: Text("Features")) {
                GuideDetailRow(icon: "bolt.fill", color: .yellow, title: "One-Tap Entry", description: "Pre-fill Amount, Category, Tags, and Account.")
                GuideDetailRow(icon: "bell.badge.fill", color: .red, title: "Reminders", description: "Attach a schedule (e.g., 'Monthly on the 1st'). The notification will deep-link directly to the pre-filled form.")
                GuideDetailRow(icon: "arrow.left.arrow.right", color: .blue, title: "Transfers", description: "Use templates to standardize credit card payments (Transfer Checking -> Credit).")
            }
        }
        .navigationTitle("Templates")
    }
}

struct PowerUserGuideView: View {
    var body: some View {
        List {
            // MARK: - Hotkeys
            Section(header: Text("Keyboard Shortcuts")) {
                HotkeyDisplayRow(keys: ["⌘", "1"], action: "Accounts Tab")
                HotkeyDisplayRow(keys: ["⌘", "2"], action: "Transactions Tab")
                HotkeyDisplayRow(keys: ["⌘", "3"], action: "Templates Tab")
                HotkeyDisplayRow(keys: ["⌘", "4"], action: "Insights Tab")
                Divider()
                HotkeyDisplayRow(keys: ["⌘", "T"], action: "New Transaction")
                HotkeyDisplayRow(keys: ["⌘", "A"], action: "New Account")
                HotkeyDisplayRow(keys: ["⌘", "G"], action: "New Group")
            }
            
            // MARK: - Utilities
            Section(header: Text("Hidden Utilities")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Math Engine", systemImage: "function")
                        .font(.headline)
                    Text("Any amount field is a calculator. Type '12.50 + 5' and hit enter.")
                        .font(.caption).foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Spotlight Search", systemImage: "magnifyingglass")
                        .font(.headline)
                    Text("In your transaction list, search by Amount, Note, Tag, or Category.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            
            // MARK: - Gestures
            Section(header: Text("Gestures")) {
                HStack {
                    Image(systemName: "hand.draw.fill")
                    Text("Swipe Left")
                    Spacer()
                    Text("Delete / Archive")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Image(systemName: "hand.tap.fill")
                    Text("Tap & Hold")
                    Spacer()
                    Text("Context Menu")
                        .foregroundColor(.secondary)
                }
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
            
            VStack(alignment: .leading, spacing: 2) {
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        .font(.system(.caption, design: .monospaced))
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

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
