import SwiftUI

struct ReconcileSelectionView: View {
    @EnvironmentObject var accountStore: AccountStore
    @Environment(\.dismiss) var dismiss
    
    // We hold a set of selected IDs (Can be Account UUIDs or Group UUIDs)
    @State private var selectedItemIDs: Set<UUID> = []
    
    // Track which groups are expanded to show their children
    @State private var expandedGroupIDs: Set<UUID> = []
    
    @State private var showingReconcileInput = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("Select a Group to reconcile its total balance, or expand it to select specific accounts.")) {
                    // 1. Root Level Groups (Recursive)
                    ForEach(rootGroups) { group in
                        ReconcileHierarchyRow(
                            item: .group(group),
                            selectedIDs: $selectedItemIDs,
                            expandedIDs: $expandedGroupIDs,
                            depth: 0
                        )
                    }
                    
                    // 2. Orphan Accounts (Not in any group)
                    ForEach(orphanAccounts) { account in
                        ReconcileHierarchyRow(
                            item: .account(account),
                            selectedIDs: $selectedItemIDs,
                            expandedIDs: $expandedGroupIDs, // Not used for accounts, but passed for API consistency
                            depth: 0
                        )
                    }
                }
            }
            .navigationTitle("Reconcile")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { dismiss() }
                            }
                            
                            ToolbarItem(placement: .primaryAction) {
                                Button("Reconcile") {
                                    if !selectedItemIDs.isEmpty {
                                        showingReconcileInput = true
                                    }
                                }
                                .disabled(selectedItemIDs.isEmpty)
                            }
                        }
                        .navigationDestination(isPresented: $showingReconcileInput) {
                            // CHANGED: Pass the dismiss action to the child view
                            ReconcileInputView(
                                selectedIDs: selectedItemIDs,
                                onComplete: { dismiss() }
                            )
                        }
                    }
                }
    
    // MARK: - Data Helpers
    
    private var rootGroups: [AccountGroup] {
        accountStore.accountGroups.filter { accountStore.depth(of: $0) == 0 }
    }
    
    private var orphanAccounts: [Account] {
        let groupedAccountIDs = accountStore.accountGroups.flatMap {
            $0.allAccountIDs(in: accountStore.accountGroups, accounts: accountStore.accounts)
        }
        return accountStore.accounts.filter { !groupedAccountIDs.contains($0.id) }
    }
}

// MARK: - Recursive Row Component

struct ReconcileHierarchyRow: View {
    @EnvironmentObject var accountStore: AccountStore
    
    let item: ReconcileItem // Enum wrapper (see below)
    @Binding var selectedIDs: Set<UUID>
    @Binding var expandedIDs: Set<UUID>
    let depth: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // THE ROW ITSELF
            HStack(spacing: 12) {
                // 1. Indentation
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth * 20))
                }
                
                // 2. Expansion Chevron (Groups Only)
                if case .group(let group) = item {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy) { toggleExpansion(group.id) }
                        }
                } else {
                    // Spacer for alignment with groups
                    Spacer().frame(width: 20)
                }
                
                // 3. Icon & Name
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .foregroundColor(iconColor)
                    Text(itemName)
                        .fontWeight(isGroup ? .medium : .regular)
                }
                
                Spacer()
                
                // 4. Selection Checkmark
                Button {
                    toggleSelection()
                } label: {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary.opacity(0.3))
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle()) // Ensures the whole row is tappable (optional)
            
            // RECURSIVE CHILDREN (If Expanded)
            if isGroup, isExpanded, case .group(let group) = item {
                // Render Child Groups
                ForEach(childGroups(of: group)) { childGroup in
                    ReconcileHierarchyRow(
                        item: .group(childGroup),
                        selectedIDs: $selectedIDs,
                        expandedIDs: $expandedIDs,
                        depth: depth + 1
                    )
                }
                
                // Render Child Accounts
                ForEach(childAccounts(of: group)) { childAccount in
                    ReconcileHierarchyRow(
                        item: .account(childAccount),
                        selectedIDs: $selectedIDs,
                        expandedIDs: $expandedIDs,
                        depth: depth + 1
                    )
                }
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private var isGroup: Bool {
        if case .group = item { return true }
        return false
    }
    
    private var isExpanded: Bool {
        expandedIDs.contains(item.id)
    }
    
    private var isSelected: Bool {
        selectedIDs.contains(item.id)
    }
    
    private var itemName: String {
        switch item {
        case .group(let g): return g.name
        case .account(let a): return a.name
        }
    }
    
    private var iconName: String {
        switch item {
        case .group: return "folder.fill"
        case .account(let a): return a.accountType.icon
        }
    }
    
    private var iconColor: Color {
        switch item {
        case .group: return .purple
        case .account: return .primary
        }
    }
    
    // Toggle Logic
    private func toggleExpansion(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
    
    private func toggleSelection() {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
            
            // SMART LOGIC (Optional):
            // If you select a child, maybe ensure the parent Group is NOT selected?
            // For now, we keep it simple: strict independent selection.
        }
    }
    
    // Children Fetchers
    private func childGroups(of group: AccountGroup) -> [AccountGroup] {
        // Filter groups that are members of this group
        return accountStore.accountGroups.filter { group.memberIDs.contains($0.id) }
    }
    
    private func childAccounts(of group: AccountGroup) -> [Account] {
        // Filter accounts that are members of this group
        return accountStore.accounts.filter { group.memberIDs.contains($0.id) }
    }
}

// Wrapper Enum to handle mixed types in the recursive view
enum ReconcileItem: Identifiable {
    case group(AccountGroup)
    case account(Account)
    
    var id: UUID {
        switch self {
        case .group(let g): return g.id
        case .account(let a): return a.id
        }
    }
}
