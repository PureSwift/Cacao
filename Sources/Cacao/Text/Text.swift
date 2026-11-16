//
//  Text.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A view that displays one or more lines of read-only text.
public struct Text: Equatable, Sendable {

    /// A run of text with its own styling.
    internal struct Run: Equatable, Sendable {
        var string: String
        var font: Font?
        var weight: Font.Weight?
        var isItalic = false
        var isMonospacedDigit = false
        var color: Color?
        var underline: Text.Decoration?
        var strikethrough: Text.Decoration?
        var kerning: CGFloat?
        var tracking: CGFloat?
        var baselineOffset: CGFloat?
    }

    /// A line drawn under or through text, and its color.
    internal struct Decoration: Hashable, Sendable {
        var isActive: Bool
        var pattern: LineStyle.Pattern
        var color: Color?
    }

    internal var runs: [Run]

    /// Creates a text view that displays a string literal without localization.
    public init(verbatim content: String) {
        self.runs = [Run(string: content)]
    }

    /// Creates a text view that displays a stored string without localization.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ content: S) {
        self.init(verbatim: String(content))
    }

    /// Creates a text view that displays localized content identified by a key.
    public init(
        _ key: LocalizedStringKey,
        tableName: String? = nil,
        bundle: Bundle? = nil,
        comment: StaticString? = nil
    ) {
        let bundle = bundle ?? .main
        let string = bundle.localizedString(forKey: key.key, value: key.key, table: tableName)
        self.init(verbatim: key.hasFormatArguments ? key.key : string)
    }

    private func modifyingRuns(_ body: (inout Run) -> Void) -> Text {
        var text = self
        for index in text.runs.indices {
            body(&text.runs[index])
        }
        return text
    }

    /// Sets the default font for text in the view.
    public func font(_ font: Font?) -> Text {
        modifyingRuns { $0.font = $0.font ?? font }
    }

    /// Sets the font weight of the text.
    public func fontWeight(_ weight: Font.Weight?) -> Text {
        modifyingRuns { $0.weight = weight }
    }

    /// Applies a bold font weight to the text.
    public func bold() -> Text {
        bold(true)
    }

    /// Applies a bold font weight to the text.
    public func bold(_ isActive: Bool) -> Text {
        isActive ? fontWeight(.bold) : self
    }

    /// Applies italics to the text.
    public func italic() -> Text {
        italic(true)
    }

    /// Applies italics to the text.
    public func italic(_ isActive: Bool) -> Text {
        modifyingRuns { $0.isItalic = $0.isItalic || isActive }
    }

    /// Modifies the text view's font to use fixed-width digits.
    public func monospacedDigit() -> Text {
        modifyingRuns { $0.isMonospacedDigit = true }
    }

    /// Sets the color of the text displayed by this view.
    public func foregroundColor(_ color: Color?) -> Text {
        modifyingRuns { $0.color = $0.color ?? color }
    }

    /// Concatenates the text in two text views in a new text view.
    public static func + (lhs: Text, rhs: Text) -> Text {
        var text = lhs
        text.runs.append(contentsOf: rhs.runs)
        return text
    }
}

// MARK: - View

extension Text: View, PrimitiveView {

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        // Text that transitions between its strings: one view per string,
        // which transitions in and out when the string changes.
        let transition = context.environment.contentTransition
        if transition != .identity {
            var environment = context.environment
            environment.contentTransition = .identity
            return Resolution(children: [ChildView(
                key: runs.map(\.string).joined(),
                view: self.transition(transition.transition),
                environment: environment
            )])
        }
        // Placeholder text: laid out the same, drawn as a shape.
        if context.environment.redactionReasons.contains(.placeholder) {
            return Resolution(children: [redactedPlaceholder(of: self, in: context.environment)])
        }
        // Text in a gradient: the gradient, masked by the text's glyphs.
        if let style = context.environment.foregroundStyle,
           style.resolveGradient(in: context.environment) != nil,
           runs.contains(where: { $0.color == nil }) {
            let glyphs = foregroundColor(.white)
            return Resolution(children: [ChildView(key: 0, view: glyphs
                .overlay(_ShapeStyleView(style: style))
                .mask { glyphs }
            )])
        }
        return Resolution(behavior: TextBehavior(text: resolve(in: context.environment)))
    }

    /// The text's runs with fonts and colors resolved in an environment.
    internal func resolve(in environment: EnvironmentValues) -> ResolvedText {
        let foreground = environment.resolvedForeground
        let defaultFont = environment.font ?? .body
        return ResolvedText(
            runs: runs.map { run in
                var font = run.font ?? defaultFont
                if let weight = run.weight {
                    font = font.weight(weight)
                }
                if run.isItalic {
                    font = font.italic()
                }
                if run.isMonospacedDigit {
                    font = font.monospacedDigit()
                }
                let string: String
                switch environment.textCase {
                case .uppercase: string = run.string.uppercased()
                case .lowercase: string = run.string.lowercased()
                case nil: string = run.string
                }
                let color = run.color?.resolve(in: environment) ?? foreground
                let attributes = environment.textAttributes
                func line(_ decoration: Text.Decoration?) -> ResolvedText.Line? {
                    guard let decoration, decoration.isActive else { return nil }
                    return ResolvedText.Line(
                        color: decoration.color?.resolve(in: environment) ?? color,
                        pattern: decoration.pattern
                    )
                }
                return ResolvedText.Run(
                    string: string,
                    font: font.resolve(),
                    color: color,
                    underline: line(run.underline ?? attributes.underline),
                    strikethrough: line(run.strikethrough ?? attributes.strikethrough),
                    tracking: (run.kerning ?? attributes.kerning ?? 0) + (run.tracking ?? attributes.tracking ?? 0),
                    baselineOffset: run.baselineOffset ?? attributes.baselineOffset ?? 0
                )
            },
            alignment: environment.multilineTextAlignment,
            lineLimit: environment.lineLimit,
            lineSpacing: environment.lineSpacing,
            truncationMode: environment.truncationMode,
            minimumScaleFactor: environment.minimumScaleFactor
        )
    }
}

/// Lays out text with the graph's text engine.
internal struct TextBehavior: NodeBehavior {

    let text: ResolvedText

    func sizeThatFits(_ proposal: ProposedViewSize, node: ViewNode) -> CGSize {
        node.graph.textEngine.layout(text, in: proposal).size
    }

    func explicitAlignment(_ key: AlignmentKey, size: CGSize, proposal: ProposedViewSize, node: ViewNode) -> CGFloat? {
        if key == VerticalAlignment.firstTextBaseline.key {
            return node.graph.textEngine.layout(text, in: proposal).firstBaseline
        }
        if key == VerticalAlignment.lastTextBaseline.key {
            return node.graph.textEngine.layout(text, in: proposal).lastBaseline
        }
        return nil
    }

    func displayContent(node: ViewNode) -> DisplayList.Content? {
        .text(text)
    }
}

// MARK: - ResolvedText

/// Text with concrete fonts and colors, ready to measure and draw.
package struct ResolvedText: Hashable, Sendable {

    package struct Run: Hashable, Sendable {

        package var string: String

        package var font: Font.Resolved

        package var color: Color.Resolved

        /// A line under the run.
        package var underline: Line? = nil

        /// A line through the run.
        package var strikethrough: Line? = nil

        /// Extra space after each character.
        package var tracking: CGFloat = 0

        /// How far the run is raised above the baseline.
        package var baselineOffset: CGFloat = 0
    }

    /// A line drawn under or through a run.
    package struct Line: Hashable, Sendable {

        package var color: Color.Resolved

        package var pattern: Text.LineStyle.Pattern

        /// The lengths of dashes and gaps for a line of a thickness.
        package func dashes(thickness: CGFloat) -> [CGFloat] {
            let unit = max(thickness, 1)
            switch pattern {
            case .solid: return []
            case .dot: return [unit, unit * 2]
            case .dash: return [unit * 4, unit * 2]
            case .dashDot: return [unit * 4, unit * 2, unit, unit * 2]
            case .dashDotDot: return [unit * 4, unit * 2, unit, unit * 2, unit, unit * 2]
            }
        }
    }

    package var runs: [Run]

    package var alignment: TextAlignment

    package var lineLimit: Int?

    /// Extra space between lines.
    package var lineSpacing: CGFloat = 0

    /// Where text that doesn't fit is cut for an ellipsis.
    package var truncationMode: TruncationMode = .tail

    /// How far fonts may shrink to fit before text is truncated.
    package var minimumScaleFactor: CGFloat = 1

    /// The text with every font and spacing scaled.
    package func scaled(by factor: CGFloat) -> ResolvedText {
        var text = self
        text.minimumScaleFactor = 1
        for index in text.runs.indices {
            text.runs[index].font.size *= factor
            text.runs[index].tracking *= factor
            text.runs[index].baselineOffset *= factor
        }
        text.lineSpacing *= factor
        return text
    }

    /// The text of all runs.
    package var string: String {
        runs.map(\.string).joined()
    }
}

// MARK: - LocalizedStringKey

/// The key used to look up an entry in a strings file or strings dictionary file.
public struct LocalizedStringKey: Equatable, Sendable, ExpressibleByStringInterpolation {

    internal let key: String

    internal let hasFormatArguments: Bool

    /// Creates a localized string key from the given string value.
    public init(_ value: String) {
        self.key = value
        self.hasFormatArguments = false
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.key = stringInterpolation.output
        self.hasFormatArguments = stringInterpolation.hasArguments
    }

    /// Represents the contents of a string literal with interpolations.
    public struct StringInterpolation: StringInterpolationProtocol {

        internal var output = ""

        internal var hasArguments = false

        public init(literalCapacity: Int, interpolationCount: Int) {
            output.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            output += literal
        }

        public mutating func appendInterpolation(_ string: String) {
            hasArguments = true
            output += string
        }

        public mutating func appendInterpolation<T>(_ value: T) {
            hasArguments = true
            output += "\(value)"
        }

        public mutating func appendInterpolation(_ text: Text) {
            hasArguments = true
            output += text.runs.map(\.string).joined()
        }
    }
}

/// A view shown as a placeholder for redaction: laid out as itself, drawn
/// as a rounded shape.
@MainActor
internal func redactedPlaceholder(of view: some View, in environment: EnvironmentValues) -> ChildView {
    var environment = environment
    environment.redactionReasons = []
    return ChildView(
        key: "redacted",
        view: view.opacity(0).background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.15))),
        environment: environment
    )
}
