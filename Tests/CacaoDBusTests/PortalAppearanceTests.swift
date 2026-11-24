import CacaoDBus
import DBus
import Testing

@Suite struct PortalAppearanceTests {

    /// The value `ReadOne` replies with: in a variant.
    private func readOne(_ value: DBusMessageArgument) -> DBusMessageArgument {
        .variant(.init(value))
    }

    /// The value the older `Read` replies with: in a variant in a variant.
    private func read(_ value: DBusMessageArgument) -> DBusMessageArgument {
        .variant(.init(.variant(.init(value))))
    }

    private func accent(_ red: Double, _ green: Double, _ blue: Double) -> DBusMessageArgument {
        .struct(.init([.double(red), .double(green), .double(blue)])!)
    }

    @Test func theColorSchemeIsDarkAtOneAndLightAtTwo() {
        #expect(PortalAppearance.colorScheme(from: readOne(.uint32(0))) == .noPreference)
        #expect(PortalAppearance.colorScheme(from: readOne(.uint32(1))) == .dark)
        #expect(PortalAppearance.colorScheme(from: readOne(.uint32(2))) == .light)
    }

    /// The portal says to read values it doesn't define as no preference.
    @Test func anUnknownColorSchemeIsNoPreference() {
        #expect(PortalAppearance.colorScheme(from: readOne(.uint32(7))) == .noPreference)
    }

    @Test func aValueOfTheWrongTypeIsNotSet() {
        #expect(PortalAppearance.colorScheme(from: readOne(.string("dark"))) == nil)
        #expect(PortalAppearance.contrast(from: readOne(.int32(1))) == nil)
        #expect(PortalAppearance.accentColor(from: readOne(.uint32(1))) == nil)
    }

    @Test func theOlderReadsExtraVariantIsUnwrapped() {
        #expect(PortalAppearance.colorScheme(from: read(.uint32(1))) == .dark)
        #expect(PortalAppearance.contrast(from: read(.uint32(1))) == .high)
        #expect(PortalAppearance.accentColor(from: read(accent(0.2, 0.4, 0.6))) == .init(red: 0.2, green: 0.4, blue: 0.6))
    }

    @Test func contrastIsNormalOrHigh() {
        #expect(PortalAppearance.contrast(from: readOne(.uint32(0))) == .normal)
        #expect(PortalAppearance.contrast(from: readOne(.uint32(1))) == .high)
        #expect(PortalAppearance.contrast(from: readOne(.uint32(9))) == .normal)
    }

    @Test func theAccentColorIsThreeSRGBComponents() {
        #expect(PortalAppearance.accentColor(from: readOne(accent(1, 0.5, 0))) == .init(red: 1, green: 0.5, blue: 0))
    }

    /// The portal says components out of the range 0 to 1 mean no accent.
    @Test func anAccentOutOfRangeIsNotSet() {
        #expect(PortalAppearance.accentColor(from: readOne(accent(-1, -1, -1))) == nil)
        #expect(PortalAppearance.accentColor(from: readOne(accent(0.5, 1.5, 0.5))) == nil)
        let twoComponents = DBusMessageArgument.struct(.init([.double(0.5), .double(0.5)])!)
        #expect(PortalAppearance.accentColor(from: readOne(twoComponents)) == nil)
    }

    @Test func aSettingChangedSignalChangesItsKey() {
        var appearance = PortalAppearance(colorScheme: .light)
        let changed = appearance.apply(settingChanged: [
            .string("org.freedesktop.appearance"), .string("color-scheme"), readOne(.uint32(1)),
        ])
        #expect(changed)
        #expect(appearance == PortalAppearance(colorScheme: .dark))

        let accentChanged = appearance.apply(settingChanged: [
            .string("org.freedesktop.appearance"), .string("accent-color"), readOne(accent(1, 0, 0)),
        ])
        #expect(accentChanged)
        #expect(appearance.accentColor == .init(red: 1, green: 0, blue: 0))
    }

    @Test func aSettingChangedSignalForAnotherSettingChangesNothing() {
        var appearance = PortalAppearance(colorScheme: .dark)
        let signals: [[DBusMessageArgument]] = [
            [.string("org.gnome.desktop.interface"), .string("color-scheme"), readOne(.string("prefer-light"))],
            [.string("org.freedesktop.appearance"), .string("reduced-motion"), readOne(.uint32(1))],
            [.string("org.freedesktop.appearance"), .string("color-scheme"), readOne(.uint32(1))],
            [.string("org.freedesktop.appearance")],
        ]
        for signal in signals {
            let changed = appearance.apply(settingChanged: signal)
            #expect(!changed)
        }
        #expect(appearance == PortalAppearance(colorScheme: .dark))
    }
}
