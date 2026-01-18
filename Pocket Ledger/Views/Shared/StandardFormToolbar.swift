//
//  StandardFormToolbar.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//

import SwiftUI

// MARK: - 1. Thumb-Friendly Form Toolbar (Bottom Save, Top Cancel)

struct ThumbFriendlyFormToolbar: ViewModifier {
    let title: String
    let canSave: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let onSaveAndNew: (() -> Void)? // NEW: Optional "Save & Add Another"

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // 1. Keep Cancel at the top-left
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            // 2. Move Save to the bottom (Sticky Footer)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    
                    if let onSaveAndNew = onSaveAndNew {
                        // DUAL BUTTON LAYOUT (for Add Transaction)
                        HStack(spacing: 12) {
                            Button(action: onSaveAndNew) {
                                HStack(spacing: 6) {
                                    Text("Save &")
                                    Image(systemName: "plus.circle.fill")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canSave ? Color.green : Color.gray)
                                .cornerRadius(12)
                            }
                            .disabled(!canSave)
                            
                            Button(action: onSave) {
                                Text("Save")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(canSave ? Color.blue : Color.gray)
                                    .cornerRadius(12)
                            }
                            .disabled(!canSave)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground).ignoresSafeArea())
                    } else {
                        // SINGLE BUTTON LAYOUT (for Edit/Template)
                        Button(action: onSave) {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canSave ? Color.blue : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!canSave)
                        .padding()
                        .background(Color(UIColor.systemBackground).ignoresSafeArea())
                    }
                }
            }
            .interactiveDismissDisabled()
    }
}

// MARK: - 2. Floating Action Button (Bottom-Right Add)

struct FloatingAddButtonModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
            
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
            }
            .padding()
        }
    }
}

// MARK: - Extensions for Easy Usage

extension View {
    /// Applies the Thumb-Friendly layout: Cancel at top, Big Save button at bottom.
    /// - Parameters:
    ///   - onSaveAndNew: Optional closure for "Save & Add Another" functionality
    func formToolbar(
        title: String,
        canSave: Bool = true,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onSaveAndNew: (() -> Void)? = nil
    ) -> some View {
        modifier(ThumbFriendlyFormToolbar(
            title: title,
            canSave: canSave,
            onSave: onSave,
            onCancel: onCancel,
            onSaveAndNew: onSaveAndNew
        ))
    }
    
    /// Adds a floating "+" button to the bottom right of the view.
    /// Usage: .floatingAddButton { showAddSheet = true }
    func floatingAddButton(action: @escaping () -> Void) -> some View {
        modifier(FloatingAddButtonModifier(action: action))
    }
}

// MARK: - Reusable Input Components

/// A styled text field for numeric/currency entry.
struct CurrencyField: View {
    let title: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Keyboard Helpers

extension View {
    /// Adds a "Done" button to the keyboard toolbar.
    func decimalPadToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
