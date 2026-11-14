//
//  SampleApp.swift
//  Cacao
//
//  An app written for Apple's SwiftUI, with no Cacao-specific code. This
//  file is compiled three times: against Apple's SwiftUI and against Cacao
//  in the parity targets, so it must stay valid SwiftUI, and into Cacao's
//  tests, which run it.
//

#if PARITY_APPLE
import SwiftUI
#else
import Cacao
#endif
import Foundation
import Observation

// MARK: - Sample app

struct TodoItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var isDone = false
}

@Observable
final class TodoStore {
    var items: [TodoItem] = [
        TodoItem(title: "Buy cacao"),
        TodoItem(title: "Write docs", isDone: true),
    ]

    var remaining: Int { items.filter { !$0.isDone }.count }

    func add(_ title: String) {
        items.append(TodoItem(title: title))
    }
}

final class TodoSettings: ObservableObject {
    @Published var showsCompleted = true
}

struct TodoApp: App {
    @State private var store = TodoStore()
    @StateObject private var settings = TodoSettings()

    var body: some Scene {
        WindowGroup("Todos") {
            TodoList()
                .environment(store)
                .environmentObject(settings)
        }
        .defaultSize(width: 400, height: 600)
    }
}

struct TodoList: View {
    @Environment(TodoStore.self) private var store
    @EnvironmentObject private var settings: TodoSettings
    @State private var isAdding = false
    @State private var newTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(visibleItems) { item in
                        NavigationLink(value: item) {
                            TodoRow(item: item)
                        }
                    }
                } header: {
                    Text("\(store.remaining) remaining")
                }
            }
            .navigationTitle("Todos")
            .navigationDestination(for: TodoItem.self) { item in
                TodoDetail(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .keyboardShortcut("n")
                }
            }
            .sheet(isPresented: $isAdding) {
                Form {
                    TextField("Title", text: $newTitle)
                        .focused($isTitleFocused)
                        .onSubmit(save)
                    HStack {
                        Button("Cancel", role: .cancel) { isAdding = false }
                        Spacer()
                        Button("Add", action: save)
                            .disabled(newTitle.isEmpty)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .onAppear { isTitleFocused = true }
            }
            .overlay {
                if store.items.isEmpty {
                    ContentUnavailableView("No Todos", systemImage: "checklist")
                }
            }
        }
    }

    private var visibleItems: [TodoItem] {
        settings.showsCompleted ? store.items : store.items.filter { !$0.isDone }
    }

    private func save() {
        store.add(newTitle)
        newTitle = ""
        isAdding = false
    }
}

struct TodoRow: View {
    let item: TodoItem

    var body: some View {
        HStack {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? .green : .secondary)
            Text(item.title)
                .strikethrough(item.isDone)
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct TodoDetail: View {
    let item: TodoItem
    @AppStorage("detailVisits") private var visits = 0

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Title", value: item.title)
                LabeledContent("Status", value: item.isDone ? "Done" : "Open")
                ViewThatFits {
                    Text("Visited \(visits) times on a wide screen")
                    Text("\(visits) visits")
                }
            }
            .padding()
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .onAppear { visits += 1 }
        .task { await Task.yield() }
    }
}
