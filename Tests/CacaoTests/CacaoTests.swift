import Testing
@testable import Cacao

@Suite struct CacaoTests {

    @Test func version() {
        #expect(!Cacao.version.isEmpty)
    }
}
