import SwiftUI
import UniformTypeIdentifiers

// MARK: - CSV Document
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        self.text = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - JSON Document
struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var savedData: SavedData
    
    init(data: SavedData) {
        self.savedData = data
    }
    
    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.savedData = try JSONDecoder().decode(SavedData.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(savedData)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Export View
struct ExportView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    
    // UI State
    @State private var exportFormat: ExportFormat = .csv
    
    // CSV State
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    // Exporter Triggers
    @State private var showCSVExporter = false
    @State private var showJSONExporter = false
    
    // Alert State
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Documents
    @State private var csvDocument = CSVDocument(text: "")
    @State private var jsonDocument = JSONBackupDocument(data: SavedData(
        accounts: [],
        accountGroups: [],
        categories: [],
        transactions: [],
        templates: [],
        insightPresets: []
    ))

    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "CSV Report"
        case json = "JSON Backup"
        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if exportFormat == .csv {
                    Section(header: Text("Date Range"), footer: Text("Exports visible transactions only.")) {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                    }
                } else {
                    Section(header: Text("Backup Summary"), footer: Text("Creates a full backup file of all accounts, transactions, templates, and settings.")) {
                        summaryRow(label: "Transactions", value: "\(transactionStore.transactions.count)")
                        summaryRow(label: "Accounts", value: "\(accountStore.accounts.count)")
                        summaryRow(label: "Templates", value: "\(transactionStore.templates.count)")
                        summaryRow(label: "Categories", value: "\(transactionStore.categories.count)")
                    }
                }
                
                Section {
                    Button {
                        if exportFormat == .csv {
                            prepareAndExportCSV()
                        } else {
                            prepareAndExportJSON()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(exportFormat == .csv ? "Export CSV" : "Export Backup")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(exportFormat == .csv && endDate < startDate)
                }
            }
            .navigationTitle("Export Data")
            // MARK: - Exporters
            .background {
                EmptyView()
                    .fileExporter(
                        isPresented: $showCSVExporter,
                        document: csvDocument,
                        contentType: .commaSeparatedText,
                        defaultFilename: defaultCSVName()
                    ) { result in
                        handleResult(result)
                    }
            }
            .background {
                EmptyView()
                    .fileExporter(
                        isPresented: $showJSONExporter,
                        document: jsonDocument,
                        contentType: .json,
                        defaultFilename: defaultJSONName()
                    ) { result in
                        handleResult(result)
                    }
            }
            .alert("Export Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - UI Helpers
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
    
    // MARK: - Logic
    
    private func prepareAndExportCSV() {
        csvDocument = prepareCSVDocument()
        showCSVExporter = true
    }
    
    private func prepareAndExportJSON() {
        // Ensure templates are included in the snapshot
        let doc = prepareJSONDocument()
        do {
            let encoder = JSONEncoder()
            _ = try encoder.encode(doc.savedData)
            jsonDocument = doc
            showJSONExporter = true
        } catch {
            print("Encoding Error: \(error)")
            errorMessage = "Could not prepare backup: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func handleResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Exported to \(url)")
            dismiss()
        case .failure(let error):
            print("Export failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    // MARK: - Document Builders
    
    private func prepareJSONDocument() -> JSONBackupDocument {
        let snapshot = SavedData(
            accounts: accountStore.accounts,
            accountGroups: accountStore.accountGroups,
            categories: transactionStore.categories,
            transactions: transactionStore.transactions,
            templates: transactionStore.templates,
            insightPresets: transactionStore.insightPresets,
            remarkBuckets: transactionStore.remarkBuckets
        )
        return JSONBackupDocument(data: snapshot)
    }

    private func prepareCSVDocument() -> CSVDocument {
            let filtered = transactionStore.transactions
                .filter { $0.date >= startDate && $0.date <= endDate }
                .sorted(by: { $0.date < $1.date })

            var csv = "ID,Date,Type,Account,Category,Remark,Amount\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for tx in filtered {
                let accountName = accountStore.accounts.first(where: { $0.id == tx.accountID })?.name ?? "Unknown"
                let categoryName = transactionStore.categories.first(where: { $0.id == tx.categoryID })?.name ?? "Unknown"
                let dateStr = dateFormatter.string(from: tx.date)
                
                // FIX 1: Convert Decimal to Double for string formatting
                let doubleAmount = NSDecimalNumber(decimal: tx.amount).doubleValue
                let amountStr = String(format: "%.2f", doubleAmount)
                
                // Commas and newlines would break the CSV column layout
                let safeRemark = tx.remark
                    .replacingOccurrences(of: ",", with: " ")
                    .replacingOccurrences(of: "\n", with: " ")
                
                // FIX 2: Use .uuidString explicitly
                csv += "\(tx.id.uuidString),\(dateStr),\(tx.type.rawValue),\(accountName),\(categoryName),\(safeRemark),\(amountStr)\n"
            }
            return CSVDocument(text: csv)
        }

    // MARK: - Safe Filenames

    private func defaultCSVName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "Transactions_\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"
    }
    
    private func defaultJSONName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "PocketLedger_Backup_\(formatter.string(from: Date()))"
    }
}
