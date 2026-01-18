import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject var data: AppData
    
    // Controls presentation of the template usage sheet
    @State private var selectedTemplate: TransactionTemplate?
    
    // Controls presentation of the Edit sheet
    @State private var templateToEdit: TransactionTemplate?

    // MARK: - Search State
    @State private var searchText = ""

    // MARK: - Filter & Sort Logic
    var filteredTemplates: [TransactionTemplate] {
        // 1. Determine which list to start with
        let templatesToFilter: [TransactionTemplate]
        
        if searchText.isEmpty {
            templatesToFilter = data.templates
        } else {
            templatesToFilter = data.templates.filter { template in
                let nameMatch = template.name.localizedCaseInsensitiveContains(searchText)
                let accName = accountName(for: template.accountID) ?? ""
                let accMatch = accName.localizedCaseInsensitiveContains(searchText)
                let catName = categoryName(for: template.categoryID) ?? ""
                let catMatch = catName.localizedCaseInsensitiveContains(searchText)
                return nameMatch || accMatch || catMatch
            }
        }
        
        // 2. Sort the resulting list Alphabetically
        return templatesToFilter.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search templates...", text: $searchText)
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 10)

                List {
                    if data.templates.isEmpty {
                        Text("No templates yet. Create one from the Add Transaction form.")
                            .foregroundColor(.secondary)
                    } else if filteredTemplates.isEmpty {
                        Text("No templates match your search.")
                            .foregroundColor(.secondary)
                    }

                    ForEach(filteredTemplates) { template in
                        HStack {
                            // 1. The Main Template Info (Tap to use)
                            Button {
                                selectedTemplate = template
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                        .foregroundColor(.primary)
                                    HStack {
                                        Text(template.type.rawValue.capitalized)
                                        if let accountName = accountName(for: template.accountID) {
                                            Text("– \(accountName)")
                                        }
                                        if let categoryName = categoryName(for: template.categoryID) {
                                            Text("– \(categoryName)")
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    
                                    // Reminder Icon
                                    if let schedule = template.reminderSchedule {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bell.fill")
                                                .font(.caption2)
                                            Text("\(schedule.frequency.rawValue)")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.top, 2)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // 2. Visible Edit Button
                            Button {
                                templateToEdit = template
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 10)
                            }
                            .buttonStyle(.borderless)
                        }
                        // Swipe Actions
                        .swipeActions(edge: .leading) {
                            Button {
                                templateToEdit = template
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSingleTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain) // Cleaner look with custom search bar
            }
            .navigationTitle("Templates")
            
            // Sheets
            .sheet(item: $selectedTemplate) { template in
                AddTransactionView(initialType: template.type, template: template)
                    .environmentObject(data)
            }
            .sheet(item: $templateToEdit) { template in
                EditTemplateView(template: template)
                    .environmentObject(data)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func deleteSingleTemplate(_ template: TransactionTemplate) {
        data.removeTemplate(template)
    }

    private func accountName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return data.accounts.first(where: { $0.id == id })?.name
    }

    private func categoryName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return data.categories.first(where: { $0.id == id })?.name
    }
}
