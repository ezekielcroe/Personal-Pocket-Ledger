import SwiftUI

struct ManageTagsView: View {
    @EnvironmentObject var data: AppData
    @State private var searchText = ""
    @State private var showingAddSheet = false  // Changed from alert to sheet
    @State private var tagToRename: Tag?
    @State private var renameText = ""

    // SORTED + FILTERED
    var filteredTags: [Tag] {
        let list = searchText.isEmpty ? data.tags : data.tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            List {
                ForEach(filteredTags) { tag in
                    Text(tag.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { prepareRename(tag) }
                        .swipeActions(edge: .leading) {
                            Button { prepareRename(tag) } label: { Label("Rename", systemImage: "pencil") }.tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleteTag(tag) } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Tags")
            // REMOVED: Toolbar button for add
            .sheet(isPresented: $showingAddSheet) {
                AddTagView()
            }
            .alert("Rename Tag", isPresented: Binding(get: { tagToRename != nil }, set: { if !$0 { tagToRename = nil } })) {
                TextField("New Name", text: $renameText)
                Button("Cancel", role: .cancel) { tagToRename = nil }
                Button("Save") {
                    if let tag = tagToRename, !renameText.isEmpty {
                        data.updateTag(id: tag.id, name: renameText)
                    }
                    tagToRename = nil
                }
            }
            
            // ADDED: FAB for adding tags (bottom-right)
            .floatingAddButton {
                showingAddSheet = true
            }
        }
    }
    
    private func prepareRename(_ tag: Tag) {
        renameText = tag.name
        tagToRename = tag
    }
    
    private func deleteTag(_ tag: Tag) {
        data.removeTagFromTransactions(tagID: tag.id)
        if let index = data.tags.firstIndex(where: { $0.id == tag.id }) {
            data.tags.remove(at: index)
            data.save()
        }
    }
}
