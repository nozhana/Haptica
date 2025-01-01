//
//  SelectableList.swift
//  Haptica
//
//  Created by Nozhan Amiri on 12/31/24.
//

import SwiftUI

struct SelectableList<V, L: View, ID: Hashable>: View {
    @Binding var values: [V]
    var id: KeyPath<V, ID>
    var onSelected: (V) -> Void
    var onDeleted: ((V) -> Void)?
    var onRenamed: ((V, String) -> Void)?
    var shareUrlKeyPath: KeyPath<V, URL>?
    var label: (V) -> L
    
    struct RenameItem: Identifiable {
        let id = UUID()
        let value: V
    }
    
    @State private var renameItem: RenameItem?
    @State private var showRenameAlert = false
    @State private var newValue: String = ""
    
    init(values: Binding<[V]>, id: KeyPath<V, ID>, shareUrlKeyPath: KeyPath<V, URL>? = nil, onSelected: @escaping (V) -> Void, onDeleted: ((V) -> Void)? = nil, onRenamed: ((V, String) -> Void)? = nil, label: @escaping (V) -> L) {
        self._values = values
        self.id = id
        self.onSelected = onSelected
        self.onDeleted = onDeleted
        self.onRenamed = onRenamed
        self.shareUrlKeyPath = shareUrlKeyPath
        self.label = label
    }
    
    init(values: Binding<[V]>, shareUrlKeyPath: KeyPath<V, URL>? = nil, onSelected: @escaping (V) -> Void, onDeleted: ((V) -> Void)? = nil, onRenamed: ((V, String) -> Void)? = nil, label: @escaping (V) -> L) where V: Identifiable, ID == V.ID {
        self._values = values
        self.id = \.id
        self.onSelected = onSelected
        self.onDeleted = onDeleted
        self.onRenamed = onRenamed
        self.shareUrlKeyPath = shareUrlKeyPath
        self.label = label
    }
    
    init(values: Binding<[V]>, onSelected: @escaping (V) -> Void, onDeleted: ((V) -> Void)? = nil, onRenamed: ((V, String) -> Void)? = nil, label: @escaping (V) -> L) where V == URL, ID == Int {
        self._values = values
        self.id = \.hashValue
        self.onSelected = onSelected
        self.onDeleted = onDeleted
        self.onRenamed = onRenamed
        self.shareUrlKeyPath = \.self
        self.label = label
    }
    
    var body: some View {
        List {
            ForEach($values, id: id) { $value in
                Button {
                    onSelected(value)
                } label: {
                    label(value)
                }
                .contextMenu {
                    if let onDeleted {
                        Button("Delete", systemImage: "trash.fill", role: .destructive) { onDeleted(value) }
                    }
                    if onRenamed != nil {
                        Button("Rename", systemImage: "pencil") {
                            renameItem = .init(value: value)
                            showRenameAlert = true
                        }
                    }
                    if let shareUrlKeyPath {
                        ShareLink(item: value[keyPath: shareUrlKeyPath])
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if let onDeleted {
                        Button("Delete", systemImage: "trash.fill", role: .destructive) { onDeleted(value) }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if let shareUrlKeyPath {
                        ShareLink(item: value[keyPath: shareUrlKeyPath])
                    }
                    if onRenamed != nil {
                        Button("Rename", systemImage: "pencil") {
                            renameItem = .init(value: value)
                            showRenameAlert = true
                        }
                    }
                }
                .alert("Rename Item", isPresented: $showRenameAlert, presenting: renameItem) { item in
                    TextField("New Value", text: $newValue)
                    Button("Cancel", role: .cancel) {
                        renameItem = nil
                    }
                    
                    Button("OK") {
                        onRenamed?(item.value, newValue)
                        newValue = ""
                        renameItem = nil
                    }
                }
            }
        }
    }
}
