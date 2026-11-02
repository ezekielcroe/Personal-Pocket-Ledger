import SwiftUI

// MARK: - Help View (Table of Contents)

struct HelpView: View {
    /// When true, a "Get Started" button is shown in the toolbar.
    /// This is used on first launch to mark the guide as seen.
    var isOnboarding: Bool = false
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Onboarding Prompt
                if isOnboarding {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome to Pocket Ledger")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Read through this guide to understand the system, then tap Get Started when you're ready.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                    }
                }
                
                // MARK: - 0. Getting Started (first-time only — moved to top)
                Section(header: Text("New Here?")) {
                    NavigationLink(destination: GettingStartedView()) {
                        ManualRow(
                            icon: "map.fill",
                            color: .green,
                            title: "Getting Started",
                            subtitle: "Your first 10 minutes with the app."
                        )
                    }
                }
                
                // MARK: - 1. Introduction
                Section {
                    NavigationLink(destination: ManifestoView()) {
                        ManualRow(
                            icon: "sparkles",
                            color: .yellow,
                            title: "The Philosophy",
                            subtitle: "Minding your Money."
                        )
                    }
                }
                
                // MARK: - 2. The Core System
                Section(header: Text("The System")) {
                    NavigationLink(destination: AccountsGuideView()) {
                        ManualRow(
                            icon: "building.columns.fill",
                            color: .blue,
                            title: "The Four Pillars",
                            subtitle: "Debit, Goal, Limit, and Debt."
                        )
                    }
                    
                    NavigationLink(destination: TaxonomyGuideView()) {
                        ManualRow(
                            icon: "text.alignleft",
                            color: .orange,
                            title: "Taxonomy",
                            subtitle: "Categories, Remarks, and the Orthogonal Strategy."
                        )
                    }
                    
                    NavigationLink(destination: InsightsGuideView()) {
                        ManualRow(
                            icon: "chart.bar.fill",
                            color: .teal,
                            title: "Insights",
                            subtitle: "Breakdowns, Buckets, and the Remark Lookup."
                        )
                    }
                    
                    NavigationLink(destination: ReconciliationGuideView()) {
                        ManualRow(
                            icon: "checkmark.seal.fill",
                            color: .green,
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
                            color: .purple,
                            title: "Interface Ergonomics",
                            subtitle: "Thumb-first design and gestures."
                        )
                    }
                    
                    NavigationLink(destination: PowerUserGuideView()) {
                        ManualRow(
                            icon: "keyboard.fill",
                            color: .primary,
                            title: "Power User Features",
                            subtitle: "Templates, Shortcuts & Deep Linking."
                        )
                    }
                }
                
                // MARK: - Footer
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Pocket Ledger")
                                .font(.headline)
                            Text("Field Guide v2.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("User Manual")
            .toolbar {
                if isOnboarding {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Get Started") {
                            hasSeenOnboarding = true
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    }
                }
            }
        }
    }
}


// MARK: - 0. Getting Started

struct GettingStartedView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Let's start by setitng up a simple personal finance ecosystem.")
                        .font(.body)
                    Text("This guide walks you through setup so you're ready to track from day one.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Step 1 — Set Up Your Accounts")) {
                GuideDetailRow(
                    icon: "1.circle.fill", color: .blue,
                    title: "Mirror your real-world accounts",
                    description: "Start with what you actually have: a checking account, a savings account, and any credit cards. One account in real life = one account in the app."
                )
                GuideDetailRow(
                    icon: "banknote", color: .green,
                    title: "Debit accounts",
                    description: "Your checking account, cash wallet, or any account you spend freely from. Set the Initial Balance to what your bank shows right now."
                )
                GuideDetailRow(
                    icon: "creditcard.fill", color: .purple,
                    title: "Limit accounts",
                    description: "Your credit cards. Set the Target Amount to your credit limit. The balance shows how much of that limit you've used."
                )
                GuideDetailRow(
                    icon: "target", color: .blue,
                    title: "Goal accounts",
                    description: "Savings working toward something specific — a holiday, an emergency fund, a new laptop. Set a Target Amount and work to fill it up."
                )
                GuideDetailRow(
                    icon: "exclamationmark.triangle.fill", color: .orange,
                    title: "Debt accounts",
                    description: "Loans, personal debts, anything you owe. Set the Initial Balance to what you owe. Every repayment reduces it."
                )
            }
            
            Section(header: Text("Step 2 — Set Up Your Categories")) {
                GuideDetailRow(
                    icon: "folder.fill", color: .orange,
                    title: "Keep them broad",
                    description: "Categories describe the nature of the expense: Housing, Food, Transport, Income, Health. Aim for 5–8 total. You don't need one for every merchant."
                )
                GuideDetailRow(
                    icon: "plus.circle", color: .green,
                    title: "Create them from Settings",
                    description: "Go to Settings → Categories and create the ones that fit your life. You can add more at any time."
                )
            }
            
            Section(header: Text("Step 3 — Record Your First Transaction")) {
                GuideDetailRow(
                    icon: "plus.circle.fill", color: .blue,
                    title: "Tap the + button",
                    description: "On the Transactions tab, tap the floating + button at the bottom right."
                )
                GuideDetailRow(
                    icon: "arrow.down.circle.fill", color: .green,
                    title: "Choose a type",
                    description: "At the top of the form. Inflow for money coming in (a salary, a refund). Outflow for money going out (a purchase, a bill). Transfer for moving money between your own accounts."
                )
                GuideDetailRow(
                    icon: "building.columns.fill", color: .blue,
                    title: "Pick an account",
                    description: "Which of your accounts was involved? If you paid by credit card, select that Limit account. Next time, the account you last used for that type is already selected — check it, and change it if needed."
                )
                GuideDetailRow(
                    icon: "checkmark.circle.fill", color: .green,
                    title: "Fill in the rest and save",
                    description: "Type the amount and tap Next. Your most-used categories appear as buttons — one tap picks one — with the full list behind More. Then add an optional remark and save; the balance updates immediately. If Save is greyed out, the line above it says what's missing."
                )
            }
            
            Section(header: Text("Step 4 — Build a Habit")) {
                GuideDetailRow(
                    icon: "bell.fill", color: .blue,
                    title: "Use Templates for recurring transactions",
                    description: "Rent, subscriptions, salary — anything that repeats. Create a Template once, and it pre-fills the form every time (except amount). You can attach a scheduled reminder so the app nudges you."
                )
                GuideDetailRow(
                    icon: "checkmark.seal.fill", color: .green,
                    title: "Reconcile weekly",
                    description: "Once a week, open your bank app and compare balances. Use the Reconcile tool if anything is off. Green dots mean your data is trusted."
                )
                GuideDetailRow(
                    icon: "clock.arrow.circlepath", color: .secondary,
                    title: "Don't aim for perfection",
                    description: "If you miss a day, catch up. If a balance is slightly off, use the Reconcile plug. Consistency over time matters far more than precision on any single day."
                )
            }
            
            Section(header: Text("What to Ignore for Now")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("You don't need to set up everything on day one. These features exist when you're ready for them:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    bulletRow("Account Groups — for grouping related accounts together (e.g. all credit cards)")
                    bulletRow("Remarks — a free-text note for the payee or context (e.g. Starbucks, Anniversary dinner), plus optional #tags for why (#work)")
                    bulletRow("Insights & Buckets — spending charts, breakdowns, and remark groupings, more useful once you have a few weeks of data")
                    bulletRow("Multiple Books — for separating personal and business finances entirely")
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Getting Started")
    }
    
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}


// MARK: - 1. Philosophy

struct ManifestoView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Most finance apps are becoming frictionless; so you open the app, the numbers are already there, and you scroll past them.")
                        .font(.body)
                    Text("Pocket Ledger aims to encourage the opposite. You type every transaction in yourself.")
                        .font(.body)
                        .fontWeight(.medium)
                    Text("We want to make friction intentional.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Active Guardianship")) {
                GuideDetailRow(
                    icon: "hand.raised.fill", color: .yellow,
                    title: "The weight of money",
                    description: "When you manually record every purchase, you feel each one. Spending stops being invisible. Over time, this changes your relationship with money more effectively."
                )
                GuideDetailRow(
                    icon: "brain", color: .yellow,
                    title: "Behavioural, not analytical",
                    description: "The goal isn't a perfect spreadsheet. It's awareness. You don't need to know exactly where every dollar went — you need to feel whether you're on track."
                )
                GuideDetailRow(
                    icon: "eye.fill", color: .yellow,
                    title: "You are the bank",
                    description: "Pocket Ledger treats you as the authoritative source of your own financial truth. The app holds what you tell it. Reconciliation is how you verify the data."
                )
            }
            
            Section(header: Text("The Design Principles")) {
                GuideDetailRow(
                    icon: "lock.fill", color: .primary,
                    title: "Offline first",
                    description: "Your data never leaves your device unless you explicitly export it. No accounts, no subscriptions, no servers."
                )
                GuideDetailRow(
                    icon: "hand.tap.fill", color: .primary,
                    title: "Capture is the job",
                    description: "The conveniences in this app is to make the path from 'I just spent money' to 'it's recorded' feel easy and fast. Everything else is secondary."
                )
                GuideDetailRow(
                    icon: "scalemass.fill", color: .primary,
                    title: "Consistency over precision",
                    description: "A balance that's $1.50 off but tracked every day is more valuable than a perfect balance you check once a month. Use the Reconcile feature, then Move on."
                )
            }
        }
        .navigationTitle("Philosophy")
    }
}


// MARK: - 2. Four Pillars

struct AccountsGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Your accounts are not just buckets for money — they are behavioural contracts. Pocket Ledger divides the financial world into four distinct account types, each with its own rules of engagement.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            
            Section(header: Text("🟢 Debit — The Liquid Hub")) {
                GuideDetailRow(icon: "banknote", color: .green,
                               title: "Concept: Now Money",
                               description: "Checking accounts, savings accounts used for spending, and physical cash. Money flows freely in and out.")
                GuideDetailRow(icon: "arrow.triangle.2.circlepath", color: .green,
                               title: "Behaviour",
                               description: "Use this for daily operational spending. Record inflows when you get paid, outflows when you spend, and transfers when you move money to savings.")
                GuideDetailRow(icon: "exclamationmark.circle", color: .red,
                               title: "Watch for",
                               description: "A balance that drops below zero. The app highlights this in red — it means you've recorded more spending than you have available.")
            }
            
            Section(header: Text("🔵 Goal — The Vault")) {
                GuideDetailRow(icon: "target", color: .blue,
                               title: "Concept: Future Money",
                               description: "Savings earmarked for a specific purpose. A holiday fund, an emergency buffer, a new laptop. Set a Target Amount so the app can show your progress.")
                GuideDetailRow(icon: "lock.fill", color: .blue,
                               title: "The Lock Protocol",
                               description: "You cannot record outflows from a Goal account. It's locked to prevent savings from silently leaking into daily spending. To use the money, you first transfer it to a Debit account.")
                GuideDetailRow(icon: "key.fill", color: .blue,
                               title: "Maturity",
                               description: "When your balance reaches the Target Amount, the account shows a Maturity badge. You can then convert it to Debit, unlocking the funds for the purchase you saved for.")
            }
            
            Section(header: Text("🟣 Limit — The Capacity Tank")) {
                GuideDetailRow(icon: "creditcard.fill", color: .purple,
                               title: "Concept: Credit as a Finite Resource",
                               description: "Credit cards don't show a debt balance here — they show available capacity. A $2,000 limit account starts full. Each purchase depletes it. Paying the bill refills it.")
                GuideDetailRow(icon: "battery.100", color: .purple,
                               title: "Why this framing matters",
                               description: "Seeing 'I have $1,200 left on my card' is psychologically different from 'I owe $800'. The tank framing makes limits feel real and finite, not abstract.")
                GuideDetailRow(icon: "bolt.slash.fill", color: .red,
                               title: "The Circuit Breaker",
                               description: "If spending exceeds your limit, you can freeze the account into a Debt account. This blocks all further outflows until you pay down the balance.")
            }
            
            Section(header: Text("🟠 Debt — The Sink")) {
                GuideDetailRow(icon: "exclamationmark.triangle.fill", color: .orange,
                               title: "Concept: The Liability to Destroy",
                               description: "Loans, personal debts, anything you owe to someone else. The balance represents what you still owe — your goal is to reduce it to zero.")
                GuideDetailRow(icon: "arrow.down.to.line", color: .orange,
                               title: "Rule",
                               description: "You cannot spend from a Debt account. You can only transfer money into it. Each transfer is a visible victory — the balance shrinks, the obligation diminishes.")
                GuideDetailRow(icon: "checkmark.circle.fill", color: .green,
                               title: "Zero is the win condition",
                               description: "When a Debt account reaches zero, you've eliminated that liability. Archive it and move on.")
            }
        }
        .navigationTitle("Four Pillars")
    }
}


// MARK: - 3. Taxonomy

struct TaxonomyGuideView: View {
    var body: some View {
        List {
            Section(header: Text("The Orthogonal Strategy"),
                    footer: Text("Three independent dimensions of information. Each answers a different question.")) {
                GuideDetailRow(icon: "building.columns.fill", color: .blue,
                               title: "Account — Where",
                               description: "Which of your accounts was involved? (e.g. Amex Gold, Main Checking, Cash Wallet)")
                GuideDetailRow(icon: "folder.fill", color: .orange,
                               title: "Category — What",
                               description: "What is the broad nature of this transaction? (e.g. Housing, Food, Transport, Income)")
                GuideDetailRow(icon: "text.alignleft", color: .purple,
                               title: "Remark — Who / Why",
                               description: "The specific detail: who you paid, in plain words (Starbucks, Client lunch), and optionally why, as a #tag (#work, #datenight). One field, two kinds of detail.")
            }
            
            Section(header: Text("The Golden Rule")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Categories should be broad. Remarks should be specific.")
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("If you create a category for every coffee shop, your charts become unreadable. Instead, create one broad 'Food' category and write the shop name in the remark. You get clean charts and can search any shop name whenever you want.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Remarks & Autocomplete")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("As you type a remark, the app suggests remarks you've used before, ranked by how often you use them and by the category you picked. Tapping a suggestion keeps your spelling consistent, so searches find everything.")
                        .font(.subheadline)
                    Text("When a remark matches one you've used before, the form shows what you did last time — category, account and amount — with buttons to reuse them. Nothing changes until you tap.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "gearshape.fill").foregroundColor(.secondary)
                        Text("Habit: Write the payee in the remark — 'Starbucks', 'Netflix', 'FairPrice'.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.blue)
                        Text("Result: Searching 'Starbucks' in Transactions finds every coffee run, with the total right there.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("#Tags — The Why")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A payee says who; a tag says why. Add one anywhere in a remark: \"Dinner at Lolla #datenight\", \"Taxi #work\". Tags show in colour, and typing # suggests the tags you've used, so they stay consistent.")
                        .font(.subheadline)
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "number").foregroundColor(.accentColor)
                        Text("Use tags for things that cut across payees and categories — a project, a trip, a person, a claimable expense. Keep payees as plain words.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Buckets — Grouping Remarks")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A bucket is a named umbrella over remark terms. \"Coffee\" with the terms starbucks, *bean and #coffee counts every transaction whose remark matches any of them.")
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 4) {
                        termRule("star", "words starting with star — Starbucks, not Mustard")
                        termRule("\"bar\"", "only the word bar — not Barber")
                        termRule("joe's coffee", "those words, in order")
                        termRule("#work", "exactly that tag — not #workout")
                        termRule("*bean", "anywhere, even mid-word — Coffeebean")
                    }
                    Text("While you edit a bucket, a preview lists the remarks it catches, with a count beside each term. Use it to spot terms that catch too much.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "clock.arrow.2.circlepath").foregroundColor(.teal)
                        Text("Buckets are searches, not labels. Add a term today and it retroactively groups every matching transaction you've ever recorded.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "gearshape.fill").foregroundColor(.secondary)
                        Text("Manage them in Settings → Remark Buckets, or save one straight from the Remark Lookup on the Insights page.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Suggested Starting Setup")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Categories (broad, permanent):")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    tagChipRow(["🍱 Food", "🏠 Housing", "🚗 Transport", "💰 Income", "🎨 Lifestyle", "🏥 Health"])
                    
                    Text("Remarks (specific, written as you go):")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                    tagChipRow(["Starbucks", "FairPrice", "Netflix", "Client lunch", "Anniversary dinner"])
                    
                    Text("Tags (optional, for why):")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                    tagChipRow(["#work", "#datenight", "#japantrip", "#claimable"])
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Taxonomy")
    }
    
    private func termRule(_ term: String, _ meaning: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(term)
                .font(.caption.monospaced())
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(meaning)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func tagChipRow(_ items: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
        }
    }
}


// MARK: - Insights

struct InsightsGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Insights answers one question first: am I on track? Everything on the page respects the same period and filters, so the numbers agree with each other — and every number opens to the transactions behind it.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            
            Section(header: Text("Where It Went")) {
                GuideDetailRow(icon: "arrow.down.circle.fill", color: .green,
                               title: "Income",
                               description: "Money that came in, excluding transfers between your own accounts.")
                GuideDetailRow(icon: "cart.fill", color: .red,
                               title: "Spent",
                               description: "Your outflows. One-offs (transactions flagged as outliers) are shown separately, so an unusual month doesn't look like a bad one.")
                GuideDetailRow(icon: "lock.fill", color: .blue,
                               title: "Saved",
                               description: "Transfers into your Goal accounts, minus anything taken back out. Moving money between two Goals isn't counted.")
                GuideDetailRow(icon: "arrow.down.right.circle.fill", color: .orange,
                               title: "Debt paid",
                               description: "Transfers into your Debt accounts. Paying off a credit card (a Limit account) isn't counted again — that spending was already counted when you made it.")
                GuideDetailRow(icon: "equal.circle.fill", color: .green,
                               title: "Left over",
                               description: "Income minus spending, saving and debt payments. Negative means you used more than came in.")
            }
            
            Section(header: Text("A Fair Comparison")) {
                GuideDetailRow(icon: "calendar.badge.clock", color: .blue,
                               title: "By this point last month",
                               description: "While a period is still in progress, it's compared with the same stretch of the previous one — the 5th against the first five days of last month, not against all of it. Past periods are compared in full.")
                GuideDetailRow(icon: "chart.bar.fill", color: .teal,
                               title: "The trend's typical line",
                               description: "The dashed line is the average of the earlier periods in the chart, counting only periods since your first transaction. The lighter bar is the period still in progress.")
            }
            
            Section(header: Text("Can I Trust These Numbers?")) {
                GuideDetailRow(icon: "exclamationmark.triangle.fill", color: .orange,
                               title: "The trust card",
                               description: "Appears when an account used in the period hasn't been verified against your bank in 30+ days (its light is red), or when the period contains plugs. Plugs are never counted as income or spending; the card shows their total so you can see how much was unexplained.")
            }
            
            Section(header: Text("Breakdowns")) {
                GuideDetailRow(icon: "folder.fill", color: .orange,
                               title: "Category, Account, Group",
                               description: "Each mode slices the period's spending a different way. Every dollar lands in exactly one row, so the percentages sum to the whole.")
                GuideDetailRow(icon: "text.magnifyingglass", color: .teal,
                               title: "Bucket",
                               description: "Slices spending by your remark buckets. Buckets can overlap — one transaction can count toward several — so rows show absolute totals instead of percentages, and the largest bucket sets the bar scale.")
                GuideDetailRow(icon: "questionmark.circle", color: .secondary,
                               title: "Unmatched",
                               description: "Spending that no bucket caught. Tap it to see the words and #tags that come up most in those remarks, and add any of them to a bucket in one tap.")
                GuideDetailRow(icon: "hand.tap.fill", color: .blue,
                               title: "Tap any row",
                               description: "Opens the exact transactions behind the number, so the list always adds up to the row. Bucket and lookup details also show a trend.")
            }
            
            Section(header: Text("The Remark Lookup")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("At the bottom of the Insights page. Type any word — a shop, a person, a project — and get its total, count, and average for the current period, plus a trend chart over recent periods.")
                        .font(.subheadline)
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "plus.circle").foregroundColor(.teal)
                        Text("Tap Save as Bucket to keep the term as a bucket. Add sibling terms later in Settings → Remark Buckets, and history regroups instantly.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Time Travel")) {
                GuideDetailRow(icon: "chevron.left.circle", color: .blue,
                               title: "Period navigation",
                               description: "The arrows step backward and forward through weeks, months, or years. Tap the date to jump back to the current period.")
                GuideDetailRow(icon: "line.3.horizontal.decrease.circle", color: .blue,
                               title: "Filters & saved views",
                               description: "Tap the filter button at the top right. Untick accounts or categories, exclude outliers, or set amount limits. Save the combination as a named view — it also remembers the breakdown and Spending/Income setting — and re-apply or update it in one tap.")
            }
        }
        .navigationTitle("Insights")
    }
}


// MARK: - 4. Reconciliation

struct ReconciliationGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Since Pocket Ledger is offline-first, it relies on you to tell the truth. Reconciliation is the act of verifying that the app's truth matches reality — your actual bank balance.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            
            Section(header: Text("The Traffic Light System")) {
                HStack(spacing: 12) {
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Green").font(.subheadline).bold()
                        Text("Verified in the last 7 days. Trusted.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Circle().fill(Color.yellow).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yellow").font(.subheadline).bold()
                        Text("Verified within 30 days. Getting stale.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Red").font(.subheadline).bold()
                        Text("More than 30 days since last check. Needs attention.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("How to Reconcile")) {
                GuideDetailRow(icon: "1.circle.fill", color: .blue,
                               title: "Open your bank app",
                               description: "Find the current balance for the account you want to verify.")
                GuideDetailRow(icon: "2.circle.fill", color: .blue,
                               title: "Open Reconcile in Pocket Ledger",
                               description: "Tap the green seal button beside + on the Accounts tab. Every account is listed, most overdue first — fill in the ones you're checking.")
                GuideDetailRow(icon: "3.circle.fill", color: .blue,
                               title: "Enter the real balance",
                               description: "Type in what your bank shows. The app compares it to its own records.")
                GuideDetailRow(icon: "checkmark.circle.fill", color: .green,
                               title: "Confirm",
                               description: "If they match, the account turns green. If they don't, Pocket Ledger calculates the difference and offers to plug the gap automatically.")
            }
            
            Section(header: Text("The Reconcile Feature")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("If your app shows $500 but your bank shows $498.50, don't spend an hour hunting for the $1.50 discrepancy.")
                        .font(.body)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill").foregroundColor(.orange)
                        Text("The Reconcile tool will calculate the $1.50 difference and automatically add a small 'Reconciliation Adjustment' transaction to close the gap. Insights leaves these adjustments out, so a plug never shows up as income or spending. If you file a plug under one of your own categories instead, it counts like any other transaction.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("Perfection is the enemy of consistency.")
                        .font(.subheadline)
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
                Text("The interface is designed for how you actually use your phone — one hand, thumb-first, on the move.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            
            Section(header: Text("Ergonomics")) {
                GuideDetailRow(icon: "arrow.down.to.line", color: .blue,
                               title: "Bottom-heavy controls",
                               description: "The Save and Add buttons live at the bottom of the screen, just above the keyboard. No reaching for the top corners. \"Save &\" saves and starts the next entry with the same account, category and date; a banner confirms each one.")
                GuideDetailRow(icon: "plus.circle.fill", color: .blue,
                               title: "Floating + button",
                               description: "The add button on each tab is always visible in the bottom-right corner. One tap to start recording, wherever you are in the app.")
                GuideDetailRow(icon: "eye.slash", color: .secondary,
                               title: "Collapse sections",
                               description: "Any section header can be tapped to collapse that group. Use this to reduce visual noise when you only care about certain account types.")
            }
            
            Section(header: Text("The Math Engine")) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Every amount field is a calculator.", systemImage: "function")
                        .font(.headline)
                    Text("Scenario: You paid for dinner ($45.00) and split it with a friend.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("Type:")
                            .font(.subheadline).bold()
                        Text("45.00 / 2")
                            .font(.subheadline).monospaced()
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    Text("The result ($22.50) appears under the field as you type, and that's what gets saved. Use the + − × ÷ keys above the keypad; you can chain operators (12 + 5.50 + 3) and use brackets on a hardware keyboard.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Remark Autocomplete")) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("The remark field completes your remarks.", systemImage: "text.cursor")
                        .font(.headline)
                    Text("As you type, the app suggests whole remarks you've used (\"Anniversary dinner\") and single words that complete the one you're typing. Tap a suggestion to use it; a space is added so you can keep going. Type # to get your tags instead.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Return completes only a suggestion that starts with what you've typed — \"Star\" becomes \"Starbucks\", but \"bean\" won't become \"Coffeebean\", and a word you've used before is left as typed. Otherwise Return finishes the remark. On iPad and Mac hardware keyboards, Tab works the same way.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Accepting suggestions keeps your spelling consistent, which is what makes searches and buckets reliable.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Swipe Gestures")) {
                SwipeGuideRow(direction: "Right →", color: .blue, action: "Edit", icon: "pencil")
                SwipeGuideRow(direction: "Right →", color: .orange, action: "Duplicate", icon: "plus.square.on.square")
                SwipeGuideRow(direction: "← Left", color: .orange, action: "Archive", icon: "archivebox.fill")
                SwipeGuideRow(direction: "← Left", color: .red, action: "Delete", icon: "trash.fill")
            }
            
            Section(header: Text("Multi-Select")) {
                GuideDetailRow(icon: "checkmark.circle", color: .blue,
                               title: "Batch operations on transactions",
                               description: "Tap the select button (top right on the Transactions tab) to enter multi-select mode. Select multiple transactions to delete them at once.")
            }
        }
        .navigationTitle("Interface")
    }
}


// MARK: - 6. Power User

struct PowerUserGuideView: View {
    var body: some View {
        List {
            Section(header: Text("Templates")) {
                GuideDetailRow(icon: "doc.on.doc.fill", color: .blue,
                               title: "What they are",
                               description: "A template is a pre-filled transaction form. Create one for anything you record repeatedly: rent, salary, a weekly grocery run, a subscription.")
                GuideDetailRow(icon: "bell.fill", color: .blue,
                               title: "Scheduled reminders",
                               description: "Attach a reminder schedule to a template — daily, weekly on a chosen day, or monthly on a chosen date. At that time, a notification arrives.")
                GuideDetailRow(icon: "arrow.forward.circle.fill", color: .green,
                               title: "Deep linking",
                               description: "Tapping the notification opens Pocket Ledger directly into the pre-filled form for that template. Review it, adjust the amount if needed, and tap Save. Done in seconds.")
            }
            
            Section(header: Text("Duplicate Instead of Retype")) {
                GuideDetailRow(icon: "plus.square.on.square", color: .orange,
                               title: "Swipe right on any transaction",
                               description: "Duplicate opens a new, pre-filled form — same account, category, amount, and remark, with today's date. One tap to save. For a repeat purchase, this is faster than a template.")
            }
            
            Section(header: Text("Keyboard Shortcuts (iPad / Mac)"),
                    footer: Text("Pocket Ledger supports full navigation with hardware keyboards.")) {
                HotkeyDisplayRow(keys: ["⌘", "1"], action: "Accounts tab")
                HotkeyDisplayRow(keys: ["⌘", "2"], action: "Transactions tab")
                HotkeyDisplayRow(keys: ["⌘", "T"], action: "New Transaction")
                HotkeyDisplayRow(keys: ["⌘", "A"], action: "New Account")
                HotkeyDisplayRow(keys: ["⌘", "G"], action: "New Account Group")
            }
            
            Section(header: Text("Multiple Books")) {
                GuideDetailRow(icon: "books.vertical.fill", color: .primary,
                               title: "What books are for",
                               description: "A book is a completely isolated set of accounts and transactions. Use multiple books if you want to keep personal finances separate from other finances.")
                GuideDetailRow(icon: "arrow.2.squarepath", color: .secondary,
                               title: "Switching books",
                               description: "Open Settings and tap the book name at the top. Each book has its own accounts, transactions, categories, and templates.")
            }
            
            Section(header: Text("Backup & Export")) {
                GuideDetailRow(icon: "externaldrive.fill", color: .primary,
                               title: "JSON Backup",
                               description: "A full backup of everything — accounts, transactions, templates, and categories. Use this to move your data to a new device or keep a personal archive.")
                GuideDetailRow(icon: "tablecells.fill", color: .secondary,
                               title: "CSV Export",
                               description: "A flat spreadsheet export of transactions within a date range. Use this for tax purposes, sharing with an accountant, or importing into another tool.")
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
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
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
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
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
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(5)
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
            Text(direction)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(action)
            }
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color)
            .cornerRadius(5)
        }
    }
}

/// A simple flow layout for wrapping chips onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height = y + rowHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
        HelpView(isOnboarding: true)
    }
}
