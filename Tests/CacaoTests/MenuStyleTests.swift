//
//  MenuStyleTests.swift
//  Cacao
//
//  Borderless menus, as a menu bar's titles: plain text highlighted while
//  open, and moving from menu to menu across them.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct MenuStyleTests {

    @Test func borderlessMenusAreTitlesHighlightedWhileOpen() throws {
        // The menu opens outside the window, so the window draws only the
        // titles.
        let graph = layoutWithSurfaces(
            HStack {
                Menu("File") { Button("Close") { } }
                Menu("Edit") { Button("Undo") { } }
                Spacer()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        )
        /// The shapes drawn in a color that shows.
        func fills() -> Int {
            func count(_ list: DisplayList) -> Int {
                list.items.reduce(0) { total, item in
                    switch item.value {
                    case let .content(.roundedRectangle(content)): total + (content.color.opacity > 0 ? 1 : 0)
                    case let .content(.shape(content)): total + (content.color.opacity > 0 ? 1 : 0)
                    case let .effect(_, nested): total + count(nested)
                    default: total
                    }
                }
            }
            return count(graph.displayList())
        }
        // Plain text: no border, no chevron.
        let closed = fills()
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        #expect(graph.isPresentingPopup)
        // Open, its title is highlighted.
        #expect(fills() == closed + 1)
        // The menu opens below the title.
        let menu = try #require(graph.detachedPopups.first)
        #expect(menu.anchor.maxY >= title.maxY)
        #expect(menu.edge == .bottom)
        graph.press(.escape)
        graph.update()
        graph.layout(in: graph.size)
        #expect(fills() == closed)
    }

    @Test func thePointerMovesFromMenuToMenuAcrossTitles() throws {
        let graph = layoutWithSurfaces(
            HStack {
                Menu("File") { Button("Close") { } }
                Menu("Edit") { Button("Undo") { } }
                Spacer()
            }
            .menuStyle(.borderlessButton)
        )
        let file = try #require(graph.textFrames["File"])
        let edit = try #require(graph.textFrames["Edit"])
        // Without an open menu, passing over a title opens nothing.
        graph.hover(at: CGPoint(x: edit.midX, y: edit.midY))
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.isEmpty)
        graph.tap(at: CGPoint(x: file.midX, y: file.midY))
        let fileMenu = try #require(graph.detachedPopups.first)
        #expect(graph.textFrames(inPopup: fileMenu.id)["Close"] != nil)
        // Onto the next title: its menu replaces the first.
        graph.hover(at: CGPoint(x: edit.midX, y: edit.midY))
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.count == 1)
        let editMenu = try #require(graph.detachedPopups.first)
        #expect(editMenu.id != fileMenu.id)
        #expect(graph.textFrames(inPopup: editMenu.id)["Undo"] != nil)
        #expect(editMenu.anchor.contains(CGPoint(x: edit.midX, y: edit.midY)))
    }
}
