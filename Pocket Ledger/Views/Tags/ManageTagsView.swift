import SwiftUI

struct ManageTagsView: View {
    @EnvironmentObject var data: AppData
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var tagToEdit: Tag? // Changed from Rename to Edit

    // UPDATED: Filter logic checks keywords
    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return data.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } else {
            return data.tags.filter { tag in
                tag.name.localizedCaseInsensitiveContains(searchText) ||
                tag.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        ZStack {
            List {
                ForEach(filteredTags) { tag in
                    VStack(alignment: .leading) {
                        Text(tag.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // NEW: Show "Matches: [Keyword]" if matched by alias
                        if !searchText.isEmpty,
                           !tag.name.localizedCaseInsensitiveContains(searchText),
                           let match = tag.keywords.first(where: { $0.localizedCaseInsensitiveContains(searchText) }) {
                            Text("Matches: \"\(match)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { tagToEdit = tag }
                    .swipeActions(edge: .leading) {
                        Button { tagToEdit = tag } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleteTag(tag) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Tags")
            .sheet(isPresented: $showingAddSheet) { AddTagView() }
            .sheet(item: $tagToEdit) { tag in EditTagView(tag: tag) }
            .floatingAddButton { showingAddSheet = true }
        }
    }
    
    private func deleteTag(_ tag: Tag) {
        data.removeTagFromTransactions(tagID: tag.id)
        if let index = data.tags.firstIndex(where: { $0.id == tag.id }) {
            data.tags.remove(at: index)
            data.save()
        }
    }
}
