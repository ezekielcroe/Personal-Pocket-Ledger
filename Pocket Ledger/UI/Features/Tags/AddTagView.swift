import SwiftUI
import UIKit

struct AddTagView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var keywordsString: String = ""
    
    // 1. Update Focus Enum
    enum Field: Hashable {
        case name
        case keywords
    }
    
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("Tag Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next) // Visual cue
                        .onSubmit {
                            // 2. Pressing Enter on Name jumps to Keywords
                            focusedField = .keywords
                        }
                }
                
                Section(header: Text("Keywords / Aliases"), footer: Text("Comma-separated words that help find this tag.")) {
                    TextField("e.g. 'japan' for trip; 'rent' for housing", text: $keywordsString)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .keywords)
                        .submitLabel(.done) // Visual cue
                        .onSubmit {
                            // 3. Pressing Enter on Keywords saves & restarts
                            if canSave {
                                saveAndAddAnother()
                            }
                        }
                }
            }
            .formToolbar(
                title: "New Tag",
                canSave: canSave,
                onSave: { saveTag(shouldDismiss: true) },
                onCancel: { dismiss() },
                onSaveAndNew: { saveAndAddAnother() }
            )
            .onAppear {
                focusedField = .name
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func parseKeywords() -> [String] {
        keywordsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func saveAndAddAnother() {
        saveTag(shouldDismiss: false)
        
        // Reset fields
        name = ""
        keywordsString = ""
        
        // 4. Reset focus back to the top for the next tag
        focusedField = .name
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func saveTag(shouldDismiss: Bool) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        transactionStore.addTag(name: trimmedName, keywords: parseKeywords())
        
        if shouldDismiss {
            dismiss()
        }
    }
}
