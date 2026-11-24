import CacaoRender
import Testing
@testable import CacaoTokens

@Suite struct ColorMathTests {

    let white = ResolvedColor(rgb: 0xFFFFFF)

    let black = ResolvedColor(rgb: 0x000000)

    @Test func hexNumbersAreSRGBComponents() {
        let color = ResolvedColor(rgb: 0xFF8000, opacity: 0.5)
        #expect(color.red == 1)
        #expect(abs(color.green - 128.0 / 255) < 0.0001)
        #expect(color.blue == 0)
        #expect(color.opacity == 0.5)
    }

    @Test func luminanceRunsFromBlackToWhite() {
        #expect(black.relativeLuminance == 0)
        #expect(abs(white.relativeLuminance - 1) < 0.0001)
        // WCAG's worked value for mid gray, #808080.
        #expect(abs(ResolvedColor(rgb: 0x808080).relativeLuminance - 0.2159) < 0.001)
    }

    @Test func contrastRatiosMatchWCAG() {
        #expect(abs(black.contrastRatio(on: white) - 21) < 0.001)
        #expect(white.contrastRatio(on: black) == black.contrastRatio(on: white))
        #expect(white.contrastRatio(on: white) == 1)
        // #767676 is the lightest gray that reads at 4.5:1 on white.
        #expect(ResolvedColor(rgb: 0x767676).contrastRatio(on: white) >= 4.5)
        #expect(ResolvedColor(rgb: 0x777777).contrastRatio(on: white) < 4.5)
    }

    @Test func translucentColorsAreCompositedFirst() {
        let halfBlack = black.opacity(0.5)
        let composited = halfBlack.composited(over: white)
        #expect(composited.opacity == 1)
        #expect(abs(composited.red - 0.5) < 0.0001)
        #expect(halfBlack.contrastRatio(on: white) == composited.contrastRatio(on: white))
    }

    @Test func mixingMovesTowardTheOtherColor() {
        let mixed = black.mixed(with: white, by: 0.25)
        #expect(abs(mixed.red - 0.25) < 0.0001)
        #expect(black.mixed(with: white, by: 0) == black)
        #expect(black.mixed(with: white, by: 2) == white)
        #expect(black.opacity(0.4).mixed(with: white, by: 1).opacity == 0.4)
    }

    @Test func readableColorsReachTheirContrast() {
        let paleBlue = ResolvedColor(rgb: 0x9ACCFF)
        let readable = paleBlue.readable(on: white, minimum: 4.5, toward: black)
        #expect(readable.contrastRatio(on: white) >= 4.5)
        #expect(readable != paleBlue)
        // A color that already reads stays as it is.
        #expect(black.readable(on: white, minimum: 4.5, toward: black) == black)
        // Out of reach, the target.
        #expect(white.readable(on: white, minimum: 30, toward: black) == black)
    }
}
