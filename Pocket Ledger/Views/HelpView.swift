//
//  HelpView.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 18/1/26.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            // MARK: - Philosophy
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mindful Automation, Complete Offline Control")
                        .font(.headline)
                    
                    Text("Pocket Ledger is built on the belief that financial awareness comes from *doing*, not just watching. By manually recording each transaction, you develop an intimate understanding of your money that automated trackers cannot provide.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("This app gives you complete offline control. Nothing touches the internet. No bank syncing. No cloud dependencies. You are the sole architect of your financial data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    Text("**The Trade-off:** You must consciously commit to every transaction. The final 'Save' always requires your tap. This isn't a limitation—it's the point.")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - Key Feature 1: Flexible Organization
            Section(header: Text("Key Feature 1: Creative Flexibility")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The Power of Books")
                                .font(.headline)
                            
                            Text("Pocket Ledger organizes data into **Books**—completely separate financial containers. Each book maintains its own accounts, transactions, categories, and tags.")
                            
                            Text("**Why Books?**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("• **Archiving:** Create 'FY2024' and 'FY2025' books to cleanly separate yearly data")
                            Text("• **Separate Tracking:** Use a 'Japan Trip 2026' book to isolate travel spending from daily expenses")
                            Text("• **Shared Finances:** Maintain 'Personal' and 'Household' books with different account structures")
                            Text("• **Privacy:** Keep sensitive finances in a separate book")
                            
                            Divider()
                            
                            Text("Books are independent universes. A transaction in one book never affects another. You can switch between books anytime from the main menu.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Books: Separate Financial Worlds", systemImage: "book.closed") }
                )
                
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Four Account Types")
                                .font(.headline)
                            
                            Text("**Debit Accounts:** Track cash on hand (checking, wallet, savings)")
                            Text("**Goal Accounts:** Debit accounts with savings targets and contribution plans")
                            Text("**Budget Accounts:** Spending envelopes with monthly limits (groceries, entertainment)")
                            Text("**Debt Accounts:** Track loans, credit cards, and installment plans with payoff calculators")
                            
                            Divider()
                            
                            Text("Virtual Account Groups")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            Text("Create **Account Groups** to organize money into 'jobs' without moving anything:")
                            
                            Text("• **'Liquid Assets'**: Sum your Checking + Savings + Wallet")
                            Text("• **'Net Worth'**: Combine all accounts (assets minus debts)")
                            Text("• **'Travel Fund'**: Group dedicated savings + a travel credit card")
                            Text("• **'Investment Portfolio'**: Aggregate multiple brokerage accounts")
                            
                            Text("Groups are live views. They recalculate instantly as you add transactions to member accounts.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Accounts & Account Groups", systemImage: "building.columns") }
                )
                
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The underlying structure is intentionally flexible. You're not locked into predefined budgeting systems or category hierarchies.")
                            
                            Text("**Examples of Creative Organization:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("• Use Budget accounts as **envelope budgets** (Dave Ramsey style)")
                            Text("• Create Goal accounts for **sinking funds** (car maintenance, gifts)")
                            Text("• Track side hustles in separate books, then export for tax prep")
                            Text("• Use tags to track **reimbursable expenses** across all categories")
                            Text("• Create Account Groups for **family members** (track spouse's spending separately)")
                            
                            Text("The components—Books, Accounts, Groups, Categories, Tags—are Lego blocks. Build the system that fits your brain.")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Creative Flexibility Philosophy", systemImage: "square.stack.3d.up") }
                )
            }
            
            // MARK: - Key Feature 2: Keyboard-First Design
            Section(header: Text("Key Feature 2: Keyboard-First Input")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The transaction form is designed for speed. Your fingers should never leave the keyboard until you're ready to save.")
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "return")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("**Enter Key Magic**")
                                        .fontWeight(.semibold)
                                    Text("Type amount → Enter → Account picker opens")
                                    Text("Select account → Category picker auto-opens")
                                    Text("Select category → Tags picker auto-opens")
                                    Text("Complete entire transaction without lifting your thumb")
                                }
                            }
                            .padding(.vertical, 4)
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("**Context-Aware Submit**")
                                        .fontWeight(.semibold)
                                    Text("The Enter key adapts to context:")
                                    Text("• Empty search bar → Complete action")
                                    Text("• One filtered result → Auto-select it")
                                    Text("• Account form → Jump to next field")
                                }
                            }
                            .padding(.vertical, 4)
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "hand.point.up")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("**Thumb-Reachable Actions**")
                                        .fontWeight(.semibold)
                                    Text("Save buttons are full-width at the bottom")
                                    Text("Cancel buttons at the top (safe from accidental taps)")
                                    Text("FAB (floating action button) in bottom-right corner")
                                    Text("Selection pickers use half-sheets—keep thumb in comfort zone")
                                }
                            }
                            .padding(.vertical, 4)
                            
                            Divider()
                            
                            Text("**Batch Entry Mode:** Tap 'Save & Add Another' to rapid-fire enter multiple transactions. Date and Account stay selected—just enter amount and save again.")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Zero-Tap Workflow", systemImage: "keyboard") }
                )
                
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("The Amount field is a mini calculator. Never reach for your phone's calculator app.")
                            
                            Text("**Supported Operations:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("`12.50 + 5.20`")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                    Text("→ 17.70")
                                }
                                
                                HStack {
                                    Text("`45 - 12.30`")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                    Text("→ 32.70")
                                }
                                
                                HStack {
                                    Text("`15 * 3`")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                    Text("→ 45.00")
                                }
                                
                                HStack {
                                    Text("`100 / 4`")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                    Text("→ 25.00")
                                }
                            }
                            
                            Text("**Use Case:** Split a $47 restaurant bill among 3 people? Type `47/3` and get $15.67 instantly.")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    },
                    label: { Label("Built-In Calculator", systemImage: "function") }
                )
                
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("**Swipe Actions Throughout:**")
                            Text("• Swipe **Right** → Edit (blue)")
                            Text("• Swipe **Left** → Delete (red)")
                            
                            Text("Works on: Accounts, Transactions, Categories, Tags, Templates, Account Groups")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    },
                    label: { Label("Swipe Gestures", systemImage: "hand.draw") }
                )
            }
            
            // MARK: - Key Feature 3: Categories vs Tags
            Section(header: Text("Key Feature 3: Categories & Tags")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Why Both?")
                                .font(.headline)
                            
                            Text("**Categories** are the 'What'—the primary purpose of the transaction.")
                            Text("A transaction can only have **one** category because money can only be spent on one thing at a time.")
                            
                            Text("Examples: Food, Rent, Salary, Transportation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            Text("**Tags** are the 'Context'—orthogonal labels that cut across categories.")
                            Text("A transaction can have **multiple** tags because spending serves multiple functions.")
                            
                            Text("Examples: #Reimbursable, #JapanTrip, #WorkRelated, #Discretionary")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            Text("The Philosophy: Orthogonality")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            Text("Regular 'remarks' or 'notes' fields encourage freeform text that's hard to analyze. Tags force you to **chunk transactions into meaningful groups**.")
                            
                            Text("**Example Scenario:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("You buy lunch (Category: Food) on a work trip (Tag: #WorkTrip) that's reimbursable (Tag: #Reimbursable).")
                            
                            Text("Later, you can:")
                            Text("• Filter by Category 'Food' → See all food spending")
                            Text("• Filter by Tag '#WorkTrip' → See total trip cost across Food, Transport, Lodging")
                            Text("• Filter by Tag '#Reimbursable' → Generate a report for expense claims")
                            
                            Text("This two-dimensional tagging system is far more powerful than nested category hierarchies.")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("The Category vs Tag Model", systemImage: "tag.fill") }
                )
                
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("**Track project costs:** Use #KitchenReno across categories (Home Improvement, Dining, Transportation)")
                            Text("**Tax preparation:** Tag transactions with #Deductible, export to CSV at year-end")
                            Text("**Shared expenses:** Use #Roommate or #DateNight to split costs mentally")
                            Text("**Spending experiments:** Tag #30DayNoShopping to track a challenge")
                            Text("**Gift tracking:** Use #Gifts to see annual gift spending across categories")
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    },
                    label: { Label("Creative Tag Uses", systemImage: "lightbulb") }
                )
            }
            
            // MARK: - Key Feature 4: Templates
            Section(header: Text("Key Feature 4: Transaction Templates")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Templates are pre-filled transaction blueprints. They save Type, Account, Category, and Tags—everything except Amount and Date.")
                            
                            Text("**Creating a Template:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("1. Fill out a transaction form normally")
                            Text("2. Tap 'Save as Template' before saving")
                            Text("3. Name it (e.g., 'Monthly Rent')")
                            
                            Divider()
                            
                            Text("**Using a Template:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("From the Templates tab, tap any template. A new transaction form opens with:")
                            Text("• Type, Account, Category, Tags → Pre-filled")
                            Text("• Date → Set to now")
                            Text("• Amount → Empty (waiting for you to enter)")
                            
                            Text("Just type the amount and hit Save. This turns a 6-tap action into a 2-tap action.")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top, 4)
                            
                            Divider()
                            
                            Text("**Common Template Uses:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("• Fixed bills (rent, subscriptions)")
                            Text("• Variable recurring expenses (groceries, gas)")
                            Text("• Income sources (salary, freelance payment)")
                            Text("• Transfer patterns (checking → savings)")
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Quick-Entry Blueprints", systemImage: "doc.text") }
                )
            }
            
            // MARK: - Key Feature 5: Template Reminders
            Section(header: Text("Key Feature 5: Recurring Reminders")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Templates can have **recurring notifications**. This is the app's only 'automation'—and it's mindful.")
                            
                            Text("**Setting Up a Reminder:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("1. Edit any template")
                            Text("2. Enable 'Reminder'")
                            Text("3. Set frequency (Daily, Weekly, Monthly)")
                            Text("4. Choose day/time")
                            
                            Divider()
                            
                            Text("**What Happens When It Fires:**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("Your phone buzzes with: 'Time to record: Monthly Rent'")
                            
                            Text("Tap the notification → Transaction form opens with:")
                            Text("• All template fields pre-filled")
                            Text("• Date set to today")
                            Text("• Amount field focused and ready")
                            
                            Text("Type the amount, tap Save. **3 seconds total.**")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.top, 4)
                            
                            Divider()
                            
                            Text("**Why This Matters:**")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            Text("This isn't 'set-and-forget' automation. You still consciously record each transaction. The reminder just removes the mental load of remembering.")
                            
                            Text("You notice when amounts change (rent increase, usage-based bills). You don't build the false security of thinking your finances are 'handled' by robots.")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Mindful Automation", systemImage: "bell.badge") }
                )
            }
            
            // MARK: - Key Feature 6: Conscious Commits & Export
            Section(header: Text("Key Feature 6: Data Ownership")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The Core Principle")
                                .font(.headline)
                            
                            Text("Every transaction requires a **conscious commit**. You can pre-fill fields with templates, get reminded by notifications, and batch-enter multiple transactions—but the final 'Save' always requires your tap.")
                            
                            Text("This isn't a bug. It's the feature.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                            
                            Divider()
                            
                            Text("**Why No Bank Syncing?**")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text("Automated sync feels convenient, but it creates passive tracking. You glance at categorized transactions you didn't input. You lose the mental model of where your money goes.")
                            
                            Text("Manual entry forces you to **feel** every purchase. That $4.50 coffee? You type it. That $127 impulse buy? You categorize it. This friction is intentional—it builds awareness.")
                            
                            Divider()
                            
                            Text("**The Safety Net: Export Everything**")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            Text("Your data is yours. No cloud lock-in. Export anytime:")
                            
                            Text("• **JSON Export**: Full backup of accounts, categories, tags, transactions, and templates")
                            Text("• **CSV Export**: Open in Excel/Google Sheets for pivot tables, charts, and custom analysis")
                            
                            Text("Use Pocket Ledger for daily awareness. Export to spreadsheets for deep analysis. The app doesn't try to be everything—it does one thing well.")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Conscious Recording & Export", systemImage: "square.and.arrow.up") }
                )
            }
            
            // MARK: - Getting Started
            Section(header: Text("Getting Started")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("**Day 1: Set Up Structure**")
                            Text("1. Create accounts (Checking, Wallet, Credit Card)")
                            Text("2. Set initial balances")
                            Text("3. Review default categories (edit as needed)")
                            Text("4. Add 2-3 tags you'll actually use")
                            
                            Text("**Week 1: Manual Entry**")
                                .padding(.top, 8)
                            Text("Record every transaction for 7 days. Use 'Save & Add Another' for batch entry. Get comfortable with the keyboard flow.")
                            
                            Text("**Week 2: Templates**")
                                .padding(.top, 8)
                            Text("Notice patterns? Create templates for recurring expenses. Set up 2-3 reminder notifications for monthly bills.")
                            
                            Text("**Week 3: Advanced Organization**")
                                .padding(.top, 8)
                            Text("Experiment with Account Groups (Net Worth view). Try using tags for a specific project. Export to CSV and play with the data.")
                            
                            Text("**Month 2+: Make It Yours**")
                                .padding(.top, 8)
                            Text("This is when the app becomes a tool, not a chore. You've built muscle memory. You understand your spending. You've customized the structure to match your brain.")
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    },
                    label: { Label("30-Day Onboarding Plan", systemImage: "map") }
                )
            }
        }
        .navigationTitle("Help Guide")
    }
}
