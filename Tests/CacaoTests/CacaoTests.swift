import Testing
@testable import Cacao

@Suite struct CacaoTests {

    @Test func version() {
        #expect(!CacaoLibrary.version.isEmpty)
    }
}
