//
//  CacaoDemoApp.swift
//  CacaoDemo
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoSDL

@main
struct CacaoDemoApp: App {

    var body: some Scene {
        WindowGroup("Cacao") {
            ContentView()
        }
        .defaultSize(width: 480, height: 720)
    }
}

struct ContentView: View {

    var body: some View {
        VStack(spacing: 0) {
            CounterSection()
                .padding()
            ShapesSection()
                .padding(.horizontal)
                .padding(.bottom)
            Divider()
            RowsSection()
        }
    }
}

struct CounterSection: View {

    @State private var count = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Cacao")
                .font(.largeTitle)
                .bold()
            Text("SwiftUI on Linux and macOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Count: \(count)")
                .font(.title2)
            HStack(spacing: 12) {
                Button("Decrement") { count -= 1 }
                    .buttonStyle(.bordered)
                    .disabled(count == 0)
                Button("Increment") { count += 1 }
                    .buttonStyle(.borderedProminent)
                Button("Reset", role: .destructive) { count = 0 }
            }
        }
    }
}

struct ShapesSection: View {

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(.orange)
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue)
            Capsule()
                .stroke(.green, lineWidth: 4)
            Ellipse()
                .strokeBorder(.purple, lineWidth: 3)
        }
        .frame(height: 60)
    }
}

struct RowsSection: View {

    @State private var selection: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<500) { index in
                    Row(index: index, isSelected: selection == index)
                        .onTapGesture { selection = index }
                    Divider()
                }
            }
        }
    }
}

struct Row: View {

    let index: Int

    let isSelected: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hue: Double(index % 24) / 24, saturation: 0.6, brightness: 0.9))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Row \(index + 1)")
                    .font(.headline)
                Text("Tap to select; scroll with a trackpad or mouse wheel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Text("Selected")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}
