import SwiftUI

struct EditCategoryView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    var category: Category
    
    @State private var name: String
    @State private var emoji: String
    @State private var type: CategoryType

    init(category: Category) {
        self.category = category
        _name = State(initialValue: category.name)
        _emoji = State(initialValue: category.emoji)
        _type = State(initialValue: category.type)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                        .submitLabel(.next)
                    TextField("Emoji", text: $emoji)
                        .submitLabel(.done)
                }
                
                Section(header: Text("Type")) {
                    Picker("Type", selection: $type) {
                        ForEach(CategoryType.allCases) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .formToolbar(
                title: "Edit Category",
                canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                onSave: {
                    transactionStore.updateCategory(id: category.id, name: name, type: type, emoji: emoji)
                    dismiss()
                },
                onCancel: {
                    dismiss()
                }
            )
        }
    }
}
