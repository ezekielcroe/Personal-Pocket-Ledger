import SwiftUI

struct ManageBooksView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    // UI State for Adding
    @State private var showingAddAlert = false
    @State private var newBookName = ""
    
    // UI State for Deleting
    @State private var bookToDelete: BookMetadata?
    @State private var showingDeleteAlert = false
    
    // UI State for Renaming (NEW)
    @State private var bookToEdit: BookMetadata?
    @State private var showingEditAlert = false
    @State private var editBookName = ""

    var body: some View {
        List {
            Section(footer: Text("Tap a book to switch to it. Swipe right to rename.")) {
                ForEach(data.availableBooks) { book in
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
                            
                            // Checkmark for active book
                            if data.activeBook?.id == book.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    // SWIPE RIGHT (Leading): Rename
                    .swipeActions(edge: .leading) {
                        Button {
                            prepareRename(book)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    // SWIPE LEFT (Trailing): Delete
                    .swipeActions(edge: .trailing) {
                        if data.activeBook?.id != book.id {
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
        
        // ALERT: Add Book
        .alert("New Book", isPresented: $showingAddAlert) {
            TextField("Book Name", text: $newBookName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                if !newBookName.isEmpty {
                    createNewBook(name: newBookName)
                }
            }
        }
        
        // ALERT: Rename Book (NEW)
        .alert("Rename Book", isPresented: $showingEditAlert) {
            TextField("New Name", text: $editBookName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let book = bookToEdit, !editBookName.isEmpty {
                    renameBook(book, to: editBookName)
                }
            }
        }
        
        // ALERT: Delete Confirmation
        .alert("Delete Book?", isPresented: $showingDeleteAlert, presenting: bookToDelete) { book in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteBook(book)
            }
        } message: { book in
            Text("Are you sure you want to delete '\(book.name)'? This will permanently erase all transactions in this book.")
        }
    }
    
    // MARK: - Logic
    
    private func switchToBook(_ book: BookMetadata) {
        guard data.activeBook?.id != book.id else { return }
        Task {
            await data.loadBook(book)
        }
    }
    
    private func createNewBook(name: String) {
        let newBook = BookMetadata(name: name)
        data.availableBooks.append(newBook)
        Task {
            await data.loadBook(newBook)
        }
    }
    
    // Logic for Renaming
    private func prepareRename(_ book: BookMetadata) {
        bookToEdit = book
        editBookName = book.name
        showingEditAlert = true
    }
    
    private func renameBook(_ book: BookMetadata, to newName: String) {
        // 1. Find and update in the list
        if let index = data.availableBooks.firstIndex(where: { $0.id == book.id }) {
            data.availableBooks[index].name = newName
            
            // 2. If it's the active book, update that reference too so the UI refreshes instantly
            if data.activeBook?.id == book.id {
                data.activeBook?.name = newName
            }
            
            // 3. Trigger persistence
            if let current = data.activeBook {
                Task { await data.loadBook(current) }
            }
        }
    }
    
    private func deleteBook(_ book: BookMetadata) {
        data.availableBooks.removeAll { $0.id == book.id }
        
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(book.fileName)
        
        try? FileManager.default.removeItem(at: fileURL)
        
        if let current = data.activeBook {
            Task { await data.loadBook(current) }
        }
    }
}
