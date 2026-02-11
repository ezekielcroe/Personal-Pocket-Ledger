import SwiftUI

/// Form to add a new category. Users choose a name, a type (inflow or outflow)
/// and optionally provide an emoji for quick visual identification.
struct AddCategoryView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var type: CategoryType = .outflow
    @State private var emoji: String = ""
    
    // MARK: - Focus State
    enum Field: Hashable {
        case name
        case emoji
    }
    
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("Category Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            // When user taps Return on Name, move to Type picker or Emoji
                            // Since Type is a Picker (not text field), skip to Emoji
                            focusedField = .emoji
                        }
                }
                Section(header: Text("Type")) {
                    Picker("Type", selection: $type) {
                        ForEach(CategoryType.allCases) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("Emoji")) {
                    TextField("Emoji (Optional)", text: $emoji)
                        .focused($focusedField, equals: .emoji)
                        .onSubmit {
                            // When user taps Return on Emoji, attempt to save
                            if canSave {
                                saveCategory()
                            }
                        }
                }
            }
            .formToolbar(
                title: "New Category",
                canSave: canSave,
                onSave: {
                    saveCategory()
                },
                onCancel: {
                    dismiss()
                }
            )
            .onAppear {
                // Auto-focus on Name field when view appears
                focusedField = .name
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveCategory() {
        transactionStore.addCategory(name: name, type: type, emoji: emoji)
        dismiss()
    }
}
