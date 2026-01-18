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
            // MARK: - 1. Philosophy
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The Philosophy")
                        .font(.headline)
                    Text("Pocket Ledger is built on the belief that financial awareness comes from *doing*, not just watching. By manually building your ledger—transaction by transaction—you gain a mindfulness that automated trackers cannot provide.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("This app gives you complete offline control. Nothing touches the internet. You are the sole architect of your financial data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - 2. Structure (Accounts)
            Section(header: Text("Structuring Your Money")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Real vs. Virtual")
                                .font(.headline)
                            
                            Text("Start by adding your **Physical Accounts** (Banks, Wallet). You can mark accounts as **Credit** to track liabilities—these show in red when they grow, representing debt.")
                            
                            Divider()
                            
                            Text("Power User Tip: Account Groups")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text("You can create **Account Groups** to organize your money into 'Jobs'.")
                            Text("• Group your Savings + Checking into a **'Liquid Cash'** group.")
                            Text("• Group a specific Credit Card + a Travel Fund into a **'Holiday'** group.")
                            
                            Text("Groups are virtual views. They sum up the balances of the included accounts without moving any money.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Accounts & Groups", systemImage: "building.columns") }
                )
                
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("**Categories** are the 'What'. Food, Rent, Salary. A transaction can only have one category because money can't be spent on two things at once.")
                            
                            Divider()
                            
                            Text("**Tags** are the 'Context'.")
                            Text("Use tags to group transactions across categories. For example, a tag **#JapanTrip** can be applied to Food, Transport, and Lodging.")
                            Text("This allows you to see the total cost of your trip in *Insights* by filtering for that single tag.")
                        }
                        .padding(.vertical, 8)
                        .font(.subheadline)
                    },
                    label: { Label("Categories vs. Tags", systemImage: "tag") }
                )
            }
            
            // MARK: - 3. Input & Speed
            Section(header: Text("Speed & Efficiency")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("We designed the input form to keep your hands on the keyboard.")
                            
                            HStack(alignment: .top) {
                                Image(systemName: "return")
                                Text("**Enter Key:** Pressing Enter on the keyboard automatically jumps to the next field. You rarely need to tap the screen.")
                            }
                            
                            HStack(alignment: .top) {
                                Image(systemName: "plus.circle")
                                Text("**Save & New:** If you have a stack of receipts, use the 'Save & Add Another' button. It keeps your Date and Account selections but clears the amount, so you can rapid-fire enter data.")
                            }
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    },
                    label: { Label("Keyboard Mastery", systemImage: "keyboard") }
                )
                
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Don't reach for a calculator.")
                            Text("In the Amount field, you can type expressions like:")
                            Text("`12.50 + 5.20`")
                                .font(.system(.caption, design: .monospaced))
                                .padding(4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            Text("When you hit Enter or Save, the app calculates the total (**17.70**) for you instantly.")
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    },
                    label: { Label("Math Engine", systemImage: "function") }
                )
                
                DisclosureGroup(
                    content: {
                        Text("In list views (Accounts, Transactions):\n\n• Swipe **Right** to **Edit**\n• Swipe **Left** to **Delete**")
                            .font(.subheadline)
                            .padding(.vertical, 8)
                    },
                    label: { Label("Gestures", systemImage: "hand.draw") }
                )
            }
            
            // MARK: - 4. Automation
            Section(header: Text("Mindful Automation")) {
                DisclosureGroup(
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("We don't sync with banks, but we do have Templates.")
                            Text("Create a template for recurring costs like 'Rent' or 'Netflix'.")
                            
                            Divider()
                            
                            Text("**Reminders:** You can attach a recurring notification to a template. When the notification pops up, tapping it opens a pre-filled transaction form. You just confirm the amount and hit Save.")
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    },
                    label: { Label("Templates & Reminders", systemImage: "bell.badge") }
                )
            }
        }
        .navigationTitle("Help Guide")
    }
}
