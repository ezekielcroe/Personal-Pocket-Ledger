//
//  ReconcileSelectionView.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 31/1/26.
//


import SwiftUI

struct ReconcileSelectionView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    // We hold a set of selected IDs. 
    // We treat both Accounts and Groups as generic "Selectable Items"
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var showingReconcileInput = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("Selecting a group will reconcile its total balance as a single unit.")) {
                    // 1. Recursive Group List
                    ForEach(data.accountGroups) { group in
                        // Only show top-level groups to keep UI clean, 
                        // or flatten the list depending on preference. 
                        // For Model B, top-level + orphans is usually best.
                        if data.depth(of: group) == 0 {
                            groupSelectionRow(group)
                        }
                    }
                    
                    // 2. Orphan Accounts (Not in any group)
                    ForEach(orphanAccounts) { account in
                        accountSelectionRow(account)
                    }
                }
            }
            .navigationTitle("Reconcile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Next") {
                        if !selectedItemIDs.isEmpty {
                            showingReconcileInput = true
                        }
                    }
                    .disabled(selectedItemIDs.isEmpty)
                }
            }
            .navigationDestination(isPresented: $showingReconcileInput) {
                ReconcileInputView(selectedIDs: selectedItemIDs)
            }
        }
    }
    
    // MARK: - Row Components
    
    @ViewBuilder
    private func groupSelectionRow(_ group: AccountGroup) -> some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.purple)
            Text(group.name)
                .fontWeight(.medium)
            
            Spacer()
            
            // Checkmark logic
            if selectedItemIDs.contains(group.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: group.id)
        }
    }
    
    @ViewBuilder
    private func accountSelectionRow(_ account: Account) -> some View {
        HStack {
            Image(systemName: account.accountType.icon)
                .foregroundColor(.primary)
            Text(account.name)
            
            Spacer()
            
            if selectedItemIDs.contains(account.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: account.id)
        }
    }
    
    // MARK: - Helpers
    
    private var orphanAccounts: [Account] {
        // Accounts that are NOT in any group
        let groupedAccountIDs = data.accountGroups.flatMap { $0.allAccountIDs(in: data.accountGroups, accounts: data.accounts) }
        return data.accounts.filter { !groupedAccountIDs.contains($0.id) }
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }
}