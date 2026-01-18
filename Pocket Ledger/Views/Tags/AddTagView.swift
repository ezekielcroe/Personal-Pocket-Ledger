import SwiftUI

/// Form to create a new tag which can later be attached to transactions.
struct AddTagView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    
    // MARK: - Focus State
    enum Field: Hashable {
        case name
    }
    
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("Tag Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            // When user taps Return, save and add another
                            if canSave {
                                saveAndAddAnother()
                            }
                        }
                }
            }
            .formToolbar(
                title: "New Tag",
                canSave: canSave,
                onSave: {
                    saveTag(shouldDismiss: true)
                },
                onCancel: {
                    dismiss()
                },
                onSaveAndNew: {
                    saveAndAddAnother()
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveAndAddAnother() {
        saveTag(shouldDismiss: false)
        
        // Clear the field and refocus for next entry
        name = ""
        focusedField = .name
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func saveTag(shouldDismiss: Bool) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        data.addTag(name: trimmedName)
        
        if shouldDismiss {
            dismiss()
        }
    }
}
