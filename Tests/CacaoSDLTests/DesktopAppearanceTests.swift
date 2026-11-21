import CacaoHost
import Testing

@Suite struct DesktopAppearanceTests {

    @Test func thePortalsColorSchemeIsDarkAtOneAndLightAtTwo() {
        #expect(DesktopAppearance.appearance(portalReply: "(<uint32 1>,)\n") == .dark)
        #expect(DesktopAppearance.appearance(portalReply: "(<uint32 2>,)\n") == .light)
    }

    /// Zero is no preference, and nothing is no portal: the next source is asked.
    @Test func aPortalWithoutAPreferenceSaysNothing() {
        #expect(DesktopAppearance.appearance(portalReply: "(<uint32 0>,)\n") == nil)
        #expect(DesktopAppearance.appearance(portalReply: "") == nil)
    }

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
