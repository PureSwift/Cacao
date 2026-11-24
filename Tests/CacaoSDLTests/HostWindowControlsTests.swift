import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import CacaoHost
import Testing

@Suite struct HostWindowControlsTests {

    private let size = CGSize(width: 400, height: 300)

    private func edge(_ x: CGFloat, _ y: CGFloat) -> HostResizeEdge? {
        HostWindow.resizeEdge(at: CGPoint(x: x, y: y), in: size, border: 6)
    }

    @Test func edgesResizeTheWindow() {
        #expect(edge(200, 2) == .top)
        #expect(edge(200, 297) == .bottom)
        #expect(edge(1, 150) == .left)
        #expect(edge(399, 150) == .right)
        #expect(edge(200, 150) == nil)
        #expect(edge(200, 6) == nil)
    }

    @Test func cornersAreTwiceAsEasyToGrab() {
        #expect(edge(2, 2) == .topLeft)
        #expect(edge(10, 2) == .topLeft)
        #expect(edge(2, 10) == .topLeft)
        #expect(edge(13, 2) == .top)
        #expect(edge(398, 10) == .topRight)
        #expect(edge(2, 290) == .bottomLeft)
        #expect(edge(390, 298) == .bottomRight)
    }

    @Test func emptyWindowsHaveNoEdges() {
        #expect(HostWindow.resizeEdge(at: CGPoint(x: 0, y: 0), in: CGSize(width: 0, height: 0), border: 6) == nil)
    }
}
