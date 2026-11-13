import Testing
@testable import CacaoScrollPhysics

@Suite struct ScrollPhysicsTests {

    @Test func constants() {
        #expect(ScrollPhysics.panThreshold == 10)
        #expect(ScrollPhysics.normalDecelerationRate > 0 && ScrollPhysics.normalDecelerationRate < 1)
    }
}
