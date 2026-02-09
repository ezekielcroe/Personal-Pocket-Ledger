import SwiftUI

struct ManageTagsView: View {
    @EnvironmentObject var data: AppData
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var tagToEdit: Tag?
    @State private var isArchivedExpanded = false

    // MARK: - Filtering Logic
    
    private func filterAndSort(_ tags: [Tag]) -> [Tag] {
        let filtered: [Tag]
        if searchText.isEmpty {
            filtered = tags
        } else {
            filtered = tags.filter { tag in
                tag.name.localizedCaseInsensitiveContains(searchText) ||
                tag.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    var activeTags: [Tag] {
        filterAndSort(data.tags.filter { !$0.isArchived })
    }
    
    var archivedTags: [Tag] {
        filterAndSort(data.tags.filter { $0.isArchived })
    }

    var body: some View {
        ZStack {
            List {
                // ACTIVE SECTION
                if !activeTags.isEmpty {
                    Section(header: Text("Active")) {
                        ForEach(activeTags) { tag in
                            tagRow(tag)
                        }
                    }
                }
                
                // ARCHIVED SECTION
                if !archivedTags.isEmpty {
                    DisclosureGroup(isExpanded: $isArchivedExpanded) {
                        ForEach(archivedTags) { tag in
                            tagRow(tag)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                            Text("Archived Tags")
                            Spacer()
                            Text("\(archivedTags.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                // EMPTY STATE
                if activeTags.isEmpty && archivedTags.isEmpty {
                    Text("No tags found")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Tags")
            .sheet(isPresented: $showingAddSheet) { AddTagView() }
            .sheet(item: $tagToEdit) { tag in EditTagView(tag: tag) }
            .floatingAddButton { showingAddSheet = true }
        }
    }
    
    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        VStack(alignment: .leading) {
            Text(tag.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(tag.isArchived ? .secondary : .primary)
            
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
            // TOGGLE ARCHIVE ACTION
            Button {
                toggleArchive(tag)
            } label: {
                if tag.isArchived {
                    Label("Unarchive", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .tint(tag.isArchived ? .gray : .orange)
            
            Button(role: .destructive) { deleteTag(tag) } label: { Label("Delete", systemImage: "trash") }
        }
    }
    
    private func toggleArchive(_ tag: Tag) {
        if let index = data.tags.firstIndex(where: { $0.id == tag.id }) {
            withAnimation {
                data.tags[index].isArchived.toggle()
                data.save()
            }
        }
    }
    
    private func deleteTag(_ tag: Tag) {
        withAnimation {
            data.removeTagFromTransactions(tagID: tag.id)
            if let index = data.tags.firstIndex(where: { $0.id == tag.id }) {
                data.tags.remove(at: index)
                data.save()
            }
        }
    }
}
