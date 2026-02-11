import SwiftUI

struct ManageBooksView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss

    @State private var showingAddAlert = false
    @State private var newBookName = ""

    @State private var bookToDelete: BookMetadata?
    @State private var showingDeleteAlert = false

    @State private var bookToRename: BookMetadata?
    @State private var showingRenameAlert = false
    @State private var renameBookName = ""

    var body: some View {
        List {
            Section(footer: Text("Tap a book to switch to it. Swipe right to rename.")) {
                ForEach(accountStore.availableBooks) { book in
                    Button {
                        switchToBook(book)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(book.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Last opened: \(book.lastOpened.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if accountStore.activeBook?.id == book.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            bookToRename = book
                            renameBookName = book.name
                            showingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        if accountStore.activeBook?.id != book.id {
                            Button(role: .destructive) {
                                bookToDelete = book
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Books")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newBookName = ""
                    showingAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Book", isPresented: $showingAddAlert) {
            TextField("Book Name", text: $newBookName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                let name = newBookName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    accountStore.createBook(name: name, transactionStore: transactionStore)
                }
            }
        }
        .alert("Rename Book", isPresented: $showingRenameAlert) {
            TextField("New Name", text: $renameBookName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let name = renameBookName.trimmingCharacters(in: .whitespaces)
                if let book = bookToRename, !name.isEmpty {
                    accountStore.renameBook(book, to: name)
                }
            }
        }
        .alert("Delete Book?", isPresented: $showingDeleteAlert, presenting: bookToDelete) { book in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                accountStore.deleteBook(book, transactionStore: transactionStore)
            }
        } message: { book in
            Text("Are you sure you want to delete '\(book.name)'? This will permanently erase all transactions in this book.")
        }
    }

    // MARK: - Actions

    private func switchToBook(_ book: BookMetadata) {
        guard accountStore.activeBook?.id != book.id else { return }
        Task {
            await accountStore.switchToBook(book, transactionStore: transactionStore)
        }
    }
}
