import SwiftUI

struct EditTagView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    var tag: Tag
    @State private var name: String

    init(tag: Tag) {
        self.tag = tag
        _name = State(initialValue: tag.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("Tag Name", text: $name)
                        .submitLabel(.done)
                }
            }
            .formToolbar(
                title: "Edit Tag",
                canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                onSave: {
                    data.updateTag(id: tag.id, name: name)
                    dismiss()
                },
                onCancel: {
                    dismiss()
                }
            )
        }
    }
}
