import CacaoTokens
import Testing

@Suite struct WindowButtonLayoutTests {

    @Test func cacaosButtonsAreAllLeading() {
        #expect(WindowButtonLayout.standard.leading == [.close, .minimize, .maximize])
        #expect(WindowButtonLayout.standard.trailing.isEmpty)
        #expect(WindowButtonLayout.standard.setting == "close,minimize,maximize:")
    }

    @Test func aSettingSplitsAtItsColon() {
        let layout = WindowButtonLayout(setting: "close,minimize:maximize")
        #expect(layout.leading == [.close, .minimize])
        #expect(layout.trailing == [.maximize])
    }

    @Test func gnomesDefaultHasOnlyCloseAtTheTrailingEnd() {
        let layout = WindowButtonLayout(setting: "appmenu:close")
        #expect(layout.leading.isEmpty)
        #expect(layout.trailing == [.close])
        #expect(layout.buttons == [.close])
    }

    @Test func whatIsntAWindowButtonIsLeftOut() {
        let layout = WindowButtonLayout(setting: "icon, close ,spacer,maximize:minimize,close")
        #expect(layout.leading == [.close, .maximize])
        // Close is named twice: only the first counts.
        #expect(layout.trailing == [.minimize])
    }

    @Test func aSettingWithoutAColonIsAllLeading() {
        #expect(WindowButtonLayout(setting: "close,maximize") == WindowButtonLayout(leading: [.close, .maximize]))
        #expect(WindowButtonLayout(setting: "") == WindowButtonLayout(leading: []))
    }

    @Test func aLayoutRoundTripsThroughItsSetting() {
        let layout = WindowButtonLayout(leading: [.maximize], trailing: [.minimize, .close])
        #expect(WindowButtonLayout(setting: layout.setting) == layout)
    }
}
