import SwiftUI

struct ManageCategoriesView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @State private var showingAddSheet = false
    @State private var categoryToEdit: Category?
    @State private var searchText = ""
    @State private var isArchivedExpanded = false
    
    // MARK: - Filtering Logic
    
    private func filterAndSort(_ categories: [Category]) -> [Category] {
        let filtered: [Category]
        if searchText.isEmpty {
            filtered = categories
        } else {
            filtered = categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    var activeInflow: [Category] {
        filterAndSort(transactionStore.categories.filter { $0.type == .inflow && !$0.isArchived })
    }
    
    var activeOutflow: [Category] {
        filterAndSort(transactionStore.categories.filter { $0.type == .outflow && !$0.isArchived })
    }
    
    var archivedCategories: [Category] {
        filterAndSort(transactionStore.categories.filter { $0.isArchived })
    }
    
    var body: some View {
        ZStack {
            List {
                // INFLOW SECTION (Active)
                if !activeInflow.isEmpty {
                    Section(header: Text("Inflow")) {
                        ForEach(activeInflow) { category in
                            categoryRow(category)
                        }
                    }
                }
                
                // OUTFLOW SECTION (Active)
                if !activeOutflow.isEmpty {
                    Section(header: Text("Outflow")) {
                        ForEach(activeOutflow) { category in
                            categoryRow(category)
                        }
                    }
                }
                
                // ARCHIVED SECTION
                if !archivedCategories.isEmpty {
                    DisclosureGroup(isExpanded: $isArchivedExpanded) {
                        ForEach(archivedCategories) { category in
                            categoryRow(category)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                            Text("Archived Categories")
                            Spacer()
                            Text("\(archivedCategories.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                // EMPTY STATE
                if activeInflow.isEmpty && activeOutflow.isEmpty && archivedCategories.isEmpty {
                    Section {
                        Text("No categories found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Categories")
            .sheet(isPresented: $showingAddSheet) {
                AddCategoryView().environmentObject(transactionStore)
            }
            .sheet(item: $categoryToEdit) { category in
                EditCategoryView(category: category).environmentObject(transactionStore)
            }
            .floatingAddButton {
                showingAddSheet = true
            }
        }
    }
    
    // MARK: - Reusable Category Row
    
    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack {
            Text(category.emoji)
                .grayscale(category.isArchived ? 1.0 : 0.0)
                .opacity(category.isArchived ? 0.6 : 1.0)
            
            Text(category.name)
                .foregroundColor(category.isArchived ? .secondary : .primary)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { categoryToEdit = category }
        .swipeActions(edge: .leading) {
            Button { categoryToEdit = category } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            // TOGGLE ARCHIVE ACTION
            Button {
                toggleArchive(category)
            } label: {
                if category.isArchived {
                    Label("Unarchive", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .tint(category.isArchived ? .gray : .orange)
            
            Button(role: .destructive) { deleteCategory(category) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleArchive(_ category: Category) {
        if let index = transactionStore.categories.firstIndex(where: { $0.id == category.id }) {
            withAnimation {
                transactionStore.categories[index].isArchived.toggle()
                transactionStore.save()
            }
        }
    }
    
    private func deleteCategory(_ category: Category) {
        if let index = transactionStore.categories.firstIndex(where: { $0.id == category.id }) {
            withAnimation {
                transactionStore.categories.remove(at: index)
                transactionStore.save()
            }
        }
    }
}
