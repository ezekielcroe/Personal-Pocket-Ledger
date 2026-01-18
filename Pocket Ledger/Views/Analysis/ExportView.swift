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
        // FIX: Removed 'try' because regularFileContents does not throw
        let data = configuration.file.regularFileContents ?? Data()
        self.savedData = try JSONDecoder().decode(SavedData.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(savedData)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ExportView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    // UI State
    @State private var exportFormat: ExportFormat = .csv
    
    // CSV State
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    // Exporter State
    @State private var showCSVExporter = false
    @State private var showJSONExporter = false
    
    @State private var csvDocument: CSVDocument?
    @State private var jsonDocument: JSONBackupDocument?

    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "CSV Report"
        case json = "JSON Backup"
        var id: String { self.rawValue }
    }

    var body: some View {
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
                Section(footer: Text("Creates a full backup file of all accounts, transactions, and settings.")) {
                    Text("Includes \(data.transactions.count) transactions")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(action: handleExport) {
                    HStack {
                        Spacer()
                        Text(exportFormat == .csv ? "Export CSV" : "Export Backup")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                // Only disable for CSV if date range is invalid
                .disabled(exportFormat == .csv && endDate < startDate)
            }
        }
        .navigationTitle("Export Data")
        // CSV Exporter
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: defaultCSVName()
        ) { result in
            handleResult(result)
        }
        // JSON Exporter
        .fileExporter(
            isPresented: $showJSONExporter,
            document: jsonDocument,
            contentType: .json,
            defaultFilename: "PocketLedger_Backup_\(Date().formatted(date: .numeric, time: .omitted))"
        ) { result in
            handleResult(result)
        }
    }
    
    // MARK: - Logic
    
    private func handleExport() {
        if exportFormat == .csv {
            csvDocument = prepareCSVDocument()
            showCSVExporter = true
        } else {
            jsonDocument = prepareJSONDocument()
            showJSONExporter = true
        }
    }
    
    private func handleResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Exported to \(url)")
            dismiss()
        case .failure(let error):
            print("Export failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Document Prep
    
    private func prepareJSONDocument() -> JSONBackupDocument {
        let snapshot = SavedData(
            accounts: data.accounts,
            categories: data.categories,
            tags: data.tags,
            transactions: data.transactions,
            templates: data.templates,
            reminderTime: data.reminderTime,
            insightPresets: data.insightPresets
        )
        return JSONBackupDocument(data: snapshot)
    }

    private func prepareCSVDocument() -> CSVDocument {
        let filtered = data.transactions
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted(by: { $0.date < $1.date })

        var csv = "ID,Date,Type,Account,Category,Tags,Amount\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for tx in filtered {
            let accountName = data.accounts.first(where: { $0.id == tx.accountID })?.name ?? "Unknown"
            let categoryName = data.categories.first(where: { $0.id == tx.categoryID })?.name ?? "Unknown"
            let tagsString = tx.tagIDs
                .compactMap { id in data.tags.first(where: { $0.id == id })?.name }
                .joined(separator: "; ")
            
            let dateStr = dateFormatter.string(from: tx.date)
            let amountStr = String(format: "%.2f", tx.amount)
            
            // Clean strings to prevent CSV breakage
            let safeTags = tagsString.replacingOccurrences(of: ",", with: " ")
            
            csv += "\(tx.id),\(dateStr),\(tx.type.rawValue),\(accountName),\(categoryName),\(safeTags),\(amountStr)\n"
        }
        return CSVDocument(text: csv)
    }

    private func defaultCSVName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "Transactions_\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"
    }
}
