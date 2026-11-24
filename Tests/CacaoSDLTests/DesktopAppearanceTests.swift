import CacaoHost
import Testing

@Suite struct DesktopAppearanceTests {

    @Test func gnomesSettingPrefersDarkOrLight() {
        #expect(DesktopAppearance.appearance(gnomeSetting: "'prefer-dark'\n") == .dark)
        #expect(DesktopAppearance.appearance(gnomeSetting: "'prefer-light'\n") == .light)
        #expect(DesktopAppearance.appearance(gnomeSetting: "'default'\n") == .light)
        #expect(DesktopAppearance.appearance(gnomeSetting: "") == nil)
    }

    @Test func anOverrideNamesDarkOrLight() {
        #expect(DesktopAppearance.appearance(named: "dark") == .dark)
        #expect(DesktopAppearance.appearance(named: " Light\n") == .light)
        #expect(DesktopAppearance.appearance(named: "sepia") == nil)
    }
}
