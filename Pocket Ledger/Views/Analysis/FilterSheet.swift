import SwiftUI

struct FilterSheet: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss

    // We accept bindings to the "Active" filter state in InsightsView
    @Binding var excludedAccountIDs: Set<UUID>
    @Binding var excludedCategoryIDs: Set<UUID>
    @Binding var excludedTagIDs: Set<UUID>
    @Binding var excludeOutliers: Bool
    
    // State for saving a new preset
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""

    var body: some View {
        NavigationStack {
            Form {
                // 1. General Options
                Section(header: Text("General")) {
                    Toggle("Exclude Outliers", isOn: $excludeOutliers)
                }

                // 2. Accounts (Uncheck to Exclude)
                Section(header: Text("Accounts (Uncheck to Exclude)")) {
                    ForEach(data.accounts) { account in
                        Button {
                            toggleExclusion(for: account.id, in: &excludedAccountIDs)
                        } label: {
                            HStack {
                                Text(account.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if !excludedAccountIDs.contains(account.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                }

                // 3. Categories
                Section(header: Text("Categories (Uncheck to Exclude)")) {
                    ForEach(data.categories) { category in
                        Button {
                            toggleExclusion(for: category.id, in: &excludedCategoryIDs)
                        } label: {
                            HStack {
                                Text(category.emoji)
                                Text(category.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if !excludedCategoryIDs.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                }

                // 4. Tags
                Section(header: Text("Tags (Uncheck to Exclude)")) {
                    if data.tags.isEmpty {
                        Text("No tags created yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(data.tags) { tag in
                            Button {
                                toggleExclusion(for: tag.id, in: &excludedTagIDs)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if !excludedTagIDs.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 5. Reset Button
                Section {
                    Button("Reset All Filters") {
                        excludedAccountIDs.removeAll()
                        excludedCategoryIDs.removeAll()
                        excludedTagIDs.removeAll()
                        excludeOutliers = false
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save as View") {
                        newPresetName = ""
                        showingSaveAlert = true
                    }
                }
            }
            .alert("Save View", isPresented: $showingSaveAlert) {
                TextField("View Name", text: $newPresetName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if !newPresetName.isEmpty {
                        let newPreset = InsightPreset(
                            name: newPresetName,
                            excludedAccountIDs: excludedAccountIDs,
                            excludedCategoryIDs: excludedCategoryIDs,
                            excludedTagIDs: excludedTagIDs,
                            excludeOutliers: excludeOutliers
                        )
                        data.savePreset(newPreset)
                        dismiss() // Optional: dismiss sheet after saving
                    }
                }
            }
        }
    }

    private func toggleExclusion(for id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) {
            set.remove(id) // Include it back (remove from blocklist)
        } else {
            set.insert(id) // Exclude it (add to blocklist)
        }
    }
}
