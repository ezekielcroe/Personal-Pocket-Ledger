import SwiftUI

struct EditTagView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    var tag: Tag
    @State private var name: String
    @State private var keywordsString: String // NEW

    init(tag: Tag) {
        self.tag = tag
        _name = State(initialValue: tag.name)
        // Load existing keywords
        _keywordsString = State(initialValue: tag.keywords.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("Tag Name", text: $name)
                        .submitLabel(.done)
                }
                
                // NEW: Keywords Section
                Section(header: Text("Keywords"), footer: Text("Comma-separated words that help find this tag.")) {
                    TextField("e.g. vacation, japan", text: $keywordsString)
                        .autocorrectionDisabled()
                }
            }
            .formToolbar(
                title: "Edit Tag",
                canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                onSave: {
                    let keywords = keywordsString
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        
                    transactionStore.updateTag(id: tag.id, name: name, keywords: keywords)
                    dismiss()
                },
                onCancel: { dismiss() }
            )
        }
    }
}
