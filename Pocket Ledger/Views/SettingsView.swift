import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var data: AppData
    @State private var showingResetAlert = false
    @State private var showingImportPicker = false
    @State private var importError: String?
    @State private var showingImportAlert = false
    
    // MARK: - Persistent Settings
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("selectedTheme") private var selectedTheme: Int = 0
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled: Bool = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. Books & Organization
                Section(header: Text("Management")) {
                    NavigationLink(destination: ManageBooksView()) {
                        HStack {
                            Label("My Books", systemImage: "books.vertical")
                            Spacer()
                            Text(data.activeBook?.name ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: ManageCategoriesView()) {
                        Label("Categories", systemImage: "folder")
                    }
                    NavigationLink(destination: ManageTagsView()) {
                        Label("Tags", systemImage: "tag")
                    }
                }

                // MARK: - 2. Regional & Temporal
                Section(header: Text("Regional & Fiscal")) {
                    HStack {
                        Label("Currency", systemImage: "banknote")
                        Spacer()
                        TextField("$", text: $currencySymbol)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Picker(selection: $fiscalStartDay, label: Label("Fiscal Start Day", systemImage: "calendar.badge.clock")) {
                        ForEach(1...28, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }
                }
                
                // MARK: - 3. Experience
                Section(header: Text("Experience")) {
                    Picker(selection: $selectedTheme, label: Label("Theme", systemImage: "paintpalette")) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                }
                
                // MARK: - 4. Privacy & Data
                Section(header: Text("Privacy & Safety")) {
                    Toggle(isOn: $isAppLockEnabled) {
                        Label("Require FaceID", systemImage: "faceid")
                    }
                    .onChange(of: isAppLockEnabled) { enabled in
                        if enabled { requestBiometricPermission() }
                    }
                    
                    NavigationLink(destination: ExportView()) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Erase Current Book", systemImage: "trash")
                    }
                }
                
                // MARK: - 5. About
                Section(header: Text("About")) {
                    // NEW: User Guide Link
                    NavigationLink(destination: HelpView()) {
                        Label("User Guide", systemImage: "questionmark.circle")
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("More")
            
            // ALERT: Reset
            .alert("Erase Current Book?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Erase", role: .destructive) {
                    triggerHaptic(.error)
                    data.resetAllData()
                }
            } message: {
                Text("This will delete all transactions in '\(data.activeBook?.name ?? "this book")'. This action cannot be undone.")
            }
            
            // FILE PICKER: Import
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            
            // ALERT: Import Errors
            .alert("Import Failed", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Private Helpers

    /// Handles the sensory feedback for interactions.
    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    /// Processes the result of a JSON backup import.
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                do {
                    try data.restoreFromBackup(url: url)
                    triggerHaptic(.success)
                } catch {
                    importError = "Could not restore backup. Please ensure the file is a valid Pocket Ledger JSON file."
                    showingImportAlert = true
                    triggerHaptic(.error)
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
            showingImportAlert = true
            triggerHaptic(.error)
        }
    }

    /// Requests FaceID/TouchID permissions for the app lock feature.
    private func requestBiometricPermission() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Lock Pocket Ledger") { success, _ in
                DispatchQueue.main.async {
                    if !success { isAppLockEnabled = false }
                }
            }
        } else {
            isAppLockEnabled = false
        }
    }
}
