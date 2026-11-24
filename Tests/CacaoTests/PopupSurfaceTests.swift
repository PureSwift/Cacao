//
//  PopupSurfaceTests.swift
//  Cacao
//
//  Menus in surfaces of their own: what the graph asks the host to open,
//  what it draws in them and in the window, and input from them.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
extension ViewGraph {

    /// The frame of each text in a detached popup's drawing, by its string,
    /// in the graph.
    func textFrames(inPopup id: Int) -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        func collect(_ list: DisplayList) {
            for item in list.items {
                switch item.value {
                case let .content(.text(text)):
                    result[text.string] = item.frame
                case let .effect(_, nested):
                    collect(nested)
                case .content:
                    break
                }
            }
        }
        collect(popupDisplayList(id))
        return result
    }

    /// Taps the center of a text in a detached popup.
    func tap(_ text: String, inPopup id: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let frame = textFrames(inPopup: id)[text] else {
            Issue.record("No text \(text) in popup \(id)", sourceLocation: sourceLocation)
            return
        }
        tap(at: CGPoint(x: frame.midX, y: frame.midY))
    }
}

/// Lays out a view in a graph that opens popups in surfaces of their own.
@MainActor
func layoutWithSurfaces<V: View>(_ view: V, width: CGFloat = 600, height: CGFloat = 28) -> ViewGraph {
    let graph = ViewGraph(rootView: view)
    graph.opensPopupSurfaces = true
    graph.layout(in: CGSize(width: width, height: height))
    return graph
}

@MainActor
@Suite struct PopupSurfaceTests {

    /// A bar as tall as the desktop's menu bar, with a menu.
    private func bar(log: Box<[String]>, appeared: Box<[String]>? = nil) -> some View {
        HStack {
            Menu("Edit") {
                Button("Undo") { log.value.append("undo") }
                    .onAppear { appeared?.value.append("appear") }
                    .onDisappear { appeared?.value.append("disappear") }
                Button("Redo") { log.value.append("redo") }
                Menu("Transformations") {
                    Button("Upper Case") { log.value.append("upper") }
                    Button("Lower Case") { log.value.append("lower") }
                }
            }
            Spacer()
        }
    }

    @Test func menusOpenOutsideTheWindow() throws {
        let log = Box<[String]>([])
        let graph = layoutWithSurfaces(bar(log: log))
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))

        // The host is asked for a surface below the title, at the menu's
        // size, which a 28-point window couldn't hold.
        let popup = try #require(graph.detachedPopups.first)
        #expect(graph.detachedPopups.count == 1)
        #expect(popup.parentID == nil)
        #expect(popup.edge == .bottom)
        #expect(popup.anchor.contains(CGPoint(x: title.midX, y: title.midY)))
        #expect(popup.offset.height > 0)
        #expect(popup.size.height > 28)
        #expect(popup.size.width >= 160)

        // The window doesn't draw it; its surface does.
        #expect(!graph.texts.contains("Undo"))
        #expect(graph.textFrames(inPopup: popup.id)["Undo"] != nil)
        // Drawn from its own top left corner.
        let undo = try #require(graph.textFrames(inPopup: popup.id)["Undo"])
        #expect(undo.minX >= 100_000)
        let drawn = graph.popupDisplayList(popup.id, at: CGPoint(x: 16, y: 12))
        #expect(!drawn.items.isEmpty)

        // A click in the surface reaches the item.
        let point = graph.point(CGPoint(x: undo.midX - popup.origin.x, y: undo.midY - popup.origin.y), inPopup: popup.id)
        graph.tap(at: point)
        graph.update()
        #expect(log.value == ["undo"])
        #expect(graph.detachedPopups.isEmpty)
        #expect(!graph.isPresentingPopup)
    }

    @Test func aClickInTheWindowDismissesTheMenu() throws {
        let log = Box<[String]>([])
        let graph = layoutWithSurfaces(bar(log: log))
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        #expect(graph.isPresentingPopup)
        graph.tap(at: CGPoint(x: 400, y: 10))
        graph.update()
        #expect(!graph.isPresentingPopup)
        #expect(log.value.isEmpty)
    }

    @Test func theSystemDismissesTheMenu() throws {
        let graph = layoutWithSurfaces(bar(log: Box([])))
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        let popup = try #require(graph.detachedPopups.first)
        // As when the compositor's grab ends.
        graph.dismissPresentation(popup.id)
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.isEmpty)
    }

    @Test func menuContentAppearsAndDisappears() throws {
        let appeared = Box<[String]>([])
        let graph = layoutWithSurfaces(bar(log: Box([]), appeared: appeared))
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        graph.update()
        #expect(appeared.value == ["appear"], "\(appeared.value)")
        graph.press(.escape)
        graph.update()
        #expect(appeared.value == ["appear", "disappear"])
    }

    @Test func submenusOpenBesideTheirItem() throws {
        let log = Box<[String]>([])
        let graph = layoutWithSurfaces(bar(log: log))
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        let menu = try #require(graph.detachedPopups.first)
        // The pointer rests on the submenu's item.
        let item = try #require(graph.textFrames(inPopup: menu.id)["Transformations"])
        graph.hover(at: CGPoint(x: item.midX, y: item.midY))
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.count == 2)
        let submenu = try #require(graph.detachedPopups.last)
        // A surface of the menu's, beside the item, in the menu's
        // coordinates.
        #expect(submenu.parentID == menu.id)
        #expect(submenu.edge == .trailing)
        let itemInMenu = item.offsetBy(dx: -menu.origin.x, dy: -menu.origin.y)
        #expect(submenu.anchor.contains(CGPoint(x: itemInMenu.midX, y: itemInMenu.midY)))

        // Choosing from it closes both.
        graph.tap("Lower Case", inPopup: submenu.id)
        graph.update()
        #expect(log.value == ["lower"])
        #expect(!graph.isPresentingPopup)
    }

    @Test func anotherItemClosesTheSubmenu() throws {
        let graph = layoutWithSurfaces(bar(log: Box([])))
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        let menu = try #require(graph.detachedPopups.first)
        let item = try #require(graph.textFrames(inPopup: menu.id)["Transformations"])
        graph.hover(at: CGPoint(x: item.midX, y: item.midY))
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.count == 2)
        let redo = try #require(graph.textFrames(inPopup: menu.id)["Redo"])
        graph.hover(at: CGPoint(x: redo.midX, y: redo.midY))
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.count == 1)
    }

    @Test func theKeyboardMovesThroughTheMenu() throws {
        let log = Box<[String]>([])
        let graph = layoutWithSurfaces(bar(log: log))
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        // Down to the first item, down again to the second, up wraps
        // around to the last; Return chooses.
        graph.press(.down)
        graph.press(.down)
        graph.press(.returnKey)
        graph.update()
        #expect(log.value == ["redo"])
        #expect(!graph.isPresentingPopup)

        // The right arrow opens a submenu, at its first item; the left
        // arrow closes it.
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        graph.press(.up)
        graph.press(.right)
        #expect(graph.detachedPopups.count == 2)
        graph.press(.left)
        #expect(graph.detachedPopups.count == 1)
        graph.press(.right)
        graph.press(.returnKey)
        graph.update()
        #expect(log.value == ["redo", "upper"])
        #expect(!graph.isPresentingPopup)
    }

    @Test func popupsDrawInTheWindowWhenTheHostCant() throws {
        let graph = layoutWithSurfaces(bar(log: Box([])), height: 400)
        let title = try #require(graph.textFrames["Edit"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        let popup = try #require(graph.detachedPopups.first)
        graph.attachPopup(popup.id)
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.isEmpty)
        #expect(graph.texts.contains("Undo"))
        let undo = try #require(graph.textFrames["Undo"])
        #expect(undo.maxY < 400)
    }

    @Test func aShorterSurfaceLaysTheMenuOutShorter() throws {
        let graph = layoutWithSurfaces(
            Menu("Window") {
                ForEach(1...40, id: \.self) { Button("Window \($0)") { } }
            }
        )
        graph.popupMaximumHeight = 2_000
        let title = try #require(graph.textFrames["Window"])
        graph.tap(at: CGPoint(x: title.midX, y: title.midY))
        let tall = try #require(graph.detachedPopups.first)
        #expect(tall.size.height > 400)
        // The system fit it to a 300-point screen.
        graph.setPopupHeight(300, for: tall.id)
        graph.layout(in: graph.size)
        #expect(graph.detachedPopups.first?.size.height == 300)
    }
}
