import SwiftUI

struct ManageCategoriesView: View {
    @EnvironmentObject var data: AppData
    @State private var showingAddSheet = false
    @State private var categoryToEdit: Category?
    @State private var searchText = ""
    
    // SPLIT BY TYPE + SORTED ALPHABETICALLY
    var inflowCategories: [Category] {
        let list = searchText.isEmpty
            ? data.categories.filter { $0.type == .inflow }
            : data.categories.filter { $0.type == .inflow && $0.name.localizedCaseInsensitiveContains(searchText) }
        return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    var outflowCategories: [Category] {
        let list = searchText.isEmpty
            ? data.categories.filter { $0.type == .outflow }
            : data.categories.filter { $0.type == .outflow && $0.name.localizedCaseInsensitiveContains(searchText) }
        return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        ZStack {
            List {
                // INFLOW SECTION
                if !inflowCategories.isEmpty {
                    Section(header: Text("Inflow")) {
                        ForEach(inflowCategories) { category in
                            categoryRow(category)
                        }
                    }
                }
                
                // OUTFLOW SECTION
                if !outflowCategories.isEmpty {
                    Section(header: Text("Outflow")) {
                        ForEach(outflowCategories) { category in
                            categoryRow(category)
                        }
                    }
                }
                
                // EMPTY STATE (when search returns no results)
                if inflowCategories.isEmpty && outflowCategories.isEmpty {
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
            // REMOVED: Toolbar button
            .sheet(isPresented: $showingAddSheet) {
                AddCategoryView().environmentObject(data)
            }
            .sheet(item: $categoryToEdit) { category in
                EditCategoryView(category: category).environmentObject(data)
            }
            
            // ADDED: FAB for adding categories (bottom-right)
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
            Text(category.name).foregroundColor(.primary)
            Spacer()
            // Badge removed since section headers now indicate type
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
            Button(role: .destructive) { deleteCategory(category) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Actions
    
    private func deleteCategory(_ category: Category) {
        if let index = data.categories.firstIndex(where: { $0.id == category.id }) {
            data.categories.remove(at: index)
            data.save()
        }
    }
}
