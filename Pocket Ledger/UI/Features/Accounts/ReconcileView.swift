import SwiftUI
import UIKit // Needed for Haptics

// MARK: - Reconcile Session
//
// One screen, no selection step. Every active account is listed and ready
// for input: grouped accounts sit under their group (which is itself
// reconcilable as a total), ungrouped accounts are sectioned by staleness
// with the most overdue first. Rows you don't fill in are rows you skipped.

struct ReconcileSessionView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    // User Input: Target ID -> Input String
    @State private var balanceInputs: [UUID: String] = [:]

    // Hierarchy / section expansion
    @State private var expandedGroupIDs: Set<UUID> = []
    @State private var isVerifiedSectionExpanded = false

    // Adjustment flow
    @State private var targetToAdjust: ReconcileTarget?
    @State private var differenceToAdjust: Decimal = 0
    @State private var showingAdjustmentSheet = false
    @State private var showingGroupTargetPicker = false
    @State private var selectedAccountForGroupAdjustment: Account?

    /// Accounts plugged (and therefore already marked verified) this session.
    @State private var adjustedAccountIDs: Set<UUID> = []

    // Feedback
    @State private var showingSuccessAlert = false
    @State private var reconciledCount = 0

    @FocusState private var focusedFieldID: UUID?

    // MARK: - Staleness

    private enum Staleness: Int, Comparable {
        case fresh = 0      // verified < 7 days ago
        case stale = 1      // 7–29 days
        case overdue = 2    // 30+ days, or never

        static func < (lhs: Staleness, rhs: Staleness) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private func staleness(of account: Account) -> Staleness {
        guard let date = account.lastReconciledDate else { return .overdue }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if days < 7 { return .fresh }
        if days < 30 { return .stale }
        return .overdue
    }

    private func stalenessColor(_ s: Staleness) -> Color {
        switch s {
        case .fresh:   return .green
        case .stale:   return .yellow
        case .overdue: return .red
        }
    }

    /// A group is as stale as its stalest member.
    private func staleness(of group: AccountGroup) -> Staleness {
        let members = accounts(inGroupRecursive: group)
        return members.map { staleness(of: $0) }.max() ?? .fresh
    }

    // MARK: - Target Model

    enum ReconcileTarget: Identifiable, Hashable {
        case account(Account)
        case group(AccountGroup)

        var id: UUID {
            switch self {
            case .account(let a): return a.id
            case .group(let g): return g.id
            }
        }

        var name: String {
            switch self {
            case .account(let a): return a.name
            case .group(let g): return g.name
            }
        }
    }

    private func systemBalance(for target: ReconcileTarget) -> Decimal {
        switch target {
        case .account(let a):
            return FinancialCalculator.balance(for: a, in: transactionStore.transactions)
        case .group(let g):
            return FinancialCalculator.groupBalance(
                g,
                in: accountStore.accountGroups,
                accounts: accountStore.accounts,
                transactions: transactionStore.transactions
            )
        }
    }

    // MARK: - Data Helpers

    private var activeAccounts: [Account] {
        accountStore.accounts.filter { !$0.isArchived }
    }

    private var rootGroups: [AccountGroup] {
        accountStore.accountGroups
            .filter { accountStore.depth(of: $0) == 0 }
            .sorted { staleness(of: $0) > staleness(of: $1) }
    }

    /// Direct child groups of a group (memberIDs holds both kinds of ID).
    private func childGroups(of group: AccountGroup) -> [AccountGroup] {
        group.memberIDs.compactMap { id in
            accountStore.accountGroups.first(where: { $0.id == id })
        }
    }

    /// Direct member accounts of a group (active only).
    private func directAccounts(of group: AccountGroup) -> [Account] {
        group.memberIDs.compactMap { id in
            activeAccounts.first(where: { $0.id == id })
        }
    }

    /// Every active account anywhere under a group.
    private func accounts(inGroupRecursive group: AccountGroup) -> [Account] {
        let ids = group.allAccountIDs(in: accountStore.accountGroups, accounts: accountStore.accounts)
        return activeAccounts.filter { ids.contains($0.id) }
    }

    private var groupedAccountIDs: Set<UUID> {
        var ids = Set<UUID>()
        for group in accountStore.accountGroups {
            ids.formUnion(group.allAccountIDs(in: accountStore.accountGroups, accounts: accountStore.accounts))
        }
        return ids
    }

    private var ungroupedAccounts: [Account] {
        activeAccounts.filter { !groupedAccountIDs.contains($0.id) }
    }

    private func ungroupedAccounts(with s: Staleness) -> [Account] {
        ungroupedAccounts
            .filter { staleness(of: $0) == s }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Session State

    private func parsedInput(for id: UUID) -> Decimal? {
        guard let raw = balanceInputs[id], !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return MathParser.calculate(raw)
    }

    private func inputMatches(_ target: ReconcileTarget) -> Bool {
        guard let actual = parsedInput(for: target.id) else { return false }
        return abs(actual - systemBalance(for: target)) < 0.01
    }

    /// Accounts that will be (or already are) marked verified this session:
    /// matched account rows, all members of matched groups, and plugged ones.
    private var sessionVerifiedAccountIDs: Set<UUID> {
        var ids = adjustedAccountIDs
        for account in activeAccounts where inputMatches(.account(account)) {
            ids.insert(account.id)
        }
        for group in accountStore.accountGroups where inputMatches(.group(group)) {
            for member in accounts(inGroupRecursive: group) {
                ids.insert(member.id)
            }
        }
        return ids
    }

    // MARK: - Math Toolbar Binding

    private var activeMathBinding: Binding<String> {
        Binding {
            guard let id = focusedFieldID else { return "" }
            return balanceInputs[id] ?? ""
        } set: { newValue in
            guard let id = focusedFieldID else { return }
            balanceInputs[id] = newValue
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            progressSection

            if !rootGroups.isEmpty {
                Section(header: Text("Groups"),
                        footer: Text("Verify a group's total in one line, or expand it to verify accounts individually.")) {
                    ForEach(rootGroups) { group in
                        groupBlock(group, depth: 0)
                    }
                }
            }

            stalenessSection(.overdue, title: "Needs Attention")
            stalenessSection(.stale, title: "Getting Stale")
            verifiedSection

            if activeAccounts.isEmpty {
                Section {
                    Text("No active accounts to reconcile.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Reconcile")
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button(action: handleDone) {
                    Text("Finish Reconciliation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .shadow(radius: 4, y: 2)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .mathPadToolbar(for: activeMathBinding)

        .alert("Verification Complete", isPresented: $showingSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(reconciledCount) accounts have been marked as verified.")
        }

        .sheet(isPresented: $showingAdjustmentSheet) {
            if let target = targetToAdjust {
                let name = selectedAccountForGroupAdjustment?.name ?? target.name
                AdjustmentDetailSheet(
                    targetName: name,
                    difference: differenceToAdjust,
                    currencySymbol: currencySymbol,
                    onConfirm: { categoryID in
                        finalizeAdjustment(categoryID: categoryID)
                    }
                )
            }
        }

        .confirmationDialog("Apply Adjustment To...", isPresented: $showingGroupTargetPicker, titleVisibility: .visible) {
            if case .group(let group) = targetToAdjust {
                ForEach(accounts(inGroupRecursive: group)) { account in
                    Button(account.name) {
                        selectedAccountForGroupAdjustment = account
                        showingAdjustmentSheet = true
                    }
                }
                Button("Cancel", role: .cancel) { targetToAdjust = nil }
            }
        } message: {
            Text("Select which account in the group contains the discrepancy.")
        }
    }

    // MARK: - Sections

    private var progressSection: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.blue)
                Text("\(sessionVerifiedAccountIDs.count) of \(activeAccounts.count) accounts verified")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            Text("Enter the balance your bank shows. Matching rows are marked verified when you finish.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func stalenessSection(_ s: Staleness, title: String) -> some View {
        let accounts = ungroupedAccounts(with: s)
        if !accounts.isEmpty {
            Section(header: Text(title)) {
                ForEach(accounts) { account in
                    targetRow(.account(account), depth: 0)
                }
            }
        }
    }

    /// Recently verified accounts, collapsed by default but re-verifiable.
    @ViewBuilder
    private var verifiedSection: some View {
        let accounts = ungroupedAccounts(with: .fresh)
        if !accounts.isEmpty {
            Section {
                Button {
                    withAnimation { isVerifiedSectionExpanded.toggle() }
                } label: {
                    HStack {
                        Circle().fill(Color.green).frame(width: 10, height: 10)
                        Text("Recently Verified (\(accounts.count))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: isVerifiedSectionExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if isVerifiedSectionExpanded {
                    ForEach(accounts) { account in
                        targetRow(.account(account), depth: 0)
                    }
                }
            }
        }
    }

    /// A group row plus, when expanded, its child groups and member accounts.
    @ViewBuilder
    private func groupBlock(_ group: AccountGroup, depth: Int) -> some View {
        targetRow(.group(group), depth: depth)

        if expandedGroupIDs.contains(group.id) {
            ForEach(childGroups(of: group)) { child in
                AnyView(groupBlock(child, depth: depth + 1))
            }
            ForEach(directAccounts(of: group)) { account in
                targetRow(.account(account), depth: depth + 1)
            }
        }
    }

    // MARK: - Target Row

    @ViewBuilder
    private func targetRow(_ target: ReconcileTarget, depth: Int) -> some View {
        let systemBal = systemBalance(for: target)
        let input = parsedInput(for: target.id)
        let isAdjusted: Bool = {
            if case .account(let a) = target { return adjustedAccountIDs.contains(a.id) }
            return false
        }()

        let binding = Binding<String>(
            get: { balanceInputs[target.id] ?? "" },
            set: { balanceInputs[target.id] = $0 }
        )

        VStack(spacing: 10) {
            // Line 1: identity + system balance (the number being verified)
            HStack {
                switch target {
                case .group(let g):
                    Button {
                        withAnimation {
                            if expandedGroupIDs.contains(g.id) {
                                expandedGroupIDs.remove(g.id)
                            } else {
                                expandedGroupIDs.insert(g.id)
                            }
                        }
                    } label: {
                        Image(systemName: expandedGroupIDs.contains(g.id) ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "folder.fill").foregroundColor(.purple)
                    Circle().fill(stalenessColor(staleness(of: g))).frame(width: 8, height: 8)
                case .account(let a):
                    Circle().fill(stalenessColor(staleness(of: a))).frame(width: 8, height: 8)
                }

                Text(target.name)
                    .fontWeight(.medium)
                Spacer()
                Text(systemBal.formattedCurrency(symbol: currencySymbol))
                    .font(.system(.body, design: .monospaced))
            }

            // Line 2: input, or the adjusted stamp
            if isAdjusted {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    Text("Adjusted and verified")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                HStack {
                    Text("Bank shows:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Enter balance", text: binding)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedFieldID, equals: target.id)
                        .submitLabel(.done)
                        .onSubmit { focusedFieldID = nil }
                }

                // Line 3: verdict
                if let actual = input {
                    let diff = actual - systemBal
                    if abs(diff) < 0.01 {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Matches")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                                Text("Off by \(diff > 0 ? "+" : "−")\(abs(diff).formattedCurrency(symbol: currencySymbol))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            Button {
                                prepareForAdjustment(target: target, diff: diff)
                            } label: {
                                Text("Plug the Gap")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, CGFloat(depth) * 16)
    }

    // MARK: - Adjustment Flow

    private func prepareForAdjustment(target: ReconcileTarget, diff: Decimal) {
        targetToAdjust = target
        differenceToAdjust = diff

        if case .group = target {
            showingGroupTargetPicker = true
        } else {
            showingAdjustmentSheet = true
        }
    }

    private func finalizeAdjustment(categoryID: UUID?) {
        guard let target = targetToAdjust else { return }

        let accountID: UUID
        if let groupAcc = selectedAccountForGroupAdjustment {
            accountID = groupAcc.id
        } else if case .account(let acc) = target {
            accountID = acc.id
        } else { return }

        let type: TransactionType = differenceToAdjust > 0 ? .inflow : .outflow
        let amount = abs(differenceToAdjust)

        let finalCategoryID: UUID
        if let userCat = categoryID {
            finalCategoryID = userCat
        } else {
            finalCategoryID = ensureAdjustmentCategory(type: type)
        }

        transactionStore.addTransaction(
            type: type,
            accountID: accountID,
            categoryID: finalCategoryID,
            amount: amount,
            date: Date(),
            isOutlier: false,
            remark: "Reconciliation adjustment"
        )

        accountStore.markAccountAsReconciled(accountID)
        adjustedAccountIDs.insert(accountID)

        // A plugged account's row switches to the "Adjusted and verified"
        // stamp, so its input is cleared. A plugged group keeps its typed
        // input; the group balance now matches it, so the row reads Matches.
        if case .account = target {
            balanceInputs[accountID] = nil
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        targetToAdjust = nil
        selectedAccountForGroupAdjustment = nil
        showingAdjustmentSheet = false
        showingGroupTargetPicker = false
    }

    private func ensureAdjustmentCategory(type: TransactionType) -> UUID {
        let name = "Reconciliation Adjustment"
        if let existing = transactionStore.categories.first(where: { $0.name == name && $0.type.rawValue == type.rawValue }) {
            return existing.id
        }
        let catType = CategoryType(rawValue: type.rawValue) ?? .outflow
        let newCat = Category(name: name, type: catType, emoji: "⚖️")
        transactionStore.categories.append(newCat)
        transactionStore.save()
        return newCat.id
    }

    // MARK: - Finish

    private func handleDone() {
        let verified = sessionVerifiedAccountIDs
        for id in verified where !adjustedAccountIDs.contains(id) {
            accountStore.markAccountAsReconciled(id)
        }

        if verified.isEmpty {
            dismiss()
        } else {
            reconciledCount = verified.count
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            showingSuccessAlert = true
        }
    }
}

// MARK: - Adjustment Detail Sheet

struct AdjustmentDetailSheet: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss

    let targetName: String
    let difference: Decimal
    let currencySymbol: String
    let onConfirm: (UUID?) -> Void

    @State private var selectedCategoryID: UUID?

    private var transactionType: TransactionType {
        difference > 0 ? .inflow : .outflow
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Adjustment Summary")) {
                    HStack {
                        Text("Target")
                        Spacer()
                        Text(targetName).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text(abs(difference).formattedCurrency(symbol: currencySymbol))
                            .fontWeight(.bold)
                    }
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Auto-select").tag(nil as UUID?)
                        ForEach(transactionStore.categories.filter { $0.type.rawValue == transactionType.rawValue }) { cat in
                            Text(cat.emoji + " " + cat.name).tag(cat.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Confirm Adjustment")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onConfirm(selectedCategoryID)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
