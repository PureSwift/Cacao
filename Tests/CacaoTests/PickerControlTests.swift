import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import Cacao

@MainActor
@Suite struct PickerControlTests {

    func elements(_ graph: ViewGraph) -> [AccessibilityElement] {
        func flatten(_ element: AccessibilityElement) -> [AccessibilityElement] {
            [element] + element.children.flatMap(flatten)
        }
        return flatten(graph.accessibilityTree())
    }

    /// Taps the first accessibility element with a label.
    func tap(_ label: String, in graph: ViewGraph, sourceLocation: SourceLocation = #_sourceLocation) {
        graph.layout(in: graph.size)
        guard let element = elements(graph).first(where: { $0.label == label }) else {
            Issue.record("No element labeled \(label)", sourceLocation: sourceLocation)
            return
        }
        graph.tap(at: CGPoint(x: element.frame.midX, y: element.frame.midY))
    }

    /// Shape items in drawing order, with their frames.
    func shapeFrames(_ graph: ViewGraph) -> [CGRect] {
        func collect(_ list: DisplayList) -> [CGRect] {
            list.items.flatMap { item -> [CGRect] in
                switch item.value {
                case .content(.shape): [item.frame]
                case .content: []
                case let .effect(_, nested): collect(nested)
                }
            }
        }
        return collect(graph.displayList())
    }

    @Test func linearGaugeFillsToTheValue() {
        let graph = layout(Gauge(value: 30.0, in: 20...60) { Text("Speed") }.frame(width: 200))
        let shapes = shapeFrames(graph)
        #expect(shapes.count == 2)
        #expect(abs(shapes[1].width - shapes[0].width / 4) < 0.001)
    }

    @Test func circularGaugeIsARing() {
        let graph = layout(
            Gauge(value: 0.5) { Text("Level") } currentValueLabel: { Text("50") }
                .gaugeStyle(.accessoryCircularCapacity)
                .probe("gauge")
        )
        #expect(graph.frame("gauge").size == CGSize(width: 58, height: 58))
        #expect(graph.texts == ["50"])
    }

    static let utc = TimeZone(identifier: "UTC")!

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 30) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func picker<V: View>(_ view: V) -> some View {
        view
            .environment(\.calendar, Calendar(identifier: .gregorian))
            .environment(\.timeZone, Self.utc)
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    @Test func compactDatePickerShowsTheDateAndTime() {
        let selection = Box(Self.date(2026, 11, 13))
        let graph = layout(picker(DatePicker("Due", selection: selection.binding)), width: 400)
        #expect(graph.texts.first == "Due")
        #expect(graph.texts.contains("Nov 13, 2026"))
        #expect(graph.texts.contains { $0.hasPrefix("12:30") })
        // The date opens a calendar.
        tap("Nov 13, 2026", in: graph)
        #expect(graph.texts.contains("November 2026"))
    }

    @Test func graphicalDatePickerSelectsDays() {
        let selection = Box(Self.date(2026, 11, 13))
        let graph = layout(
            picker(DatePicker("Due", selection: selection.binding, displayedComponents: .date).datePickerStyle(.graphical)),
            width: 400, height: 400
        )
        #expect(graph.texts.contains("November 2026"))
        tap("20", in: graph)
        // The day changes; the time of day stays.
        #expect(selection.value == Self.date(2026, 11, 20))
        tap("Next Month", in: graph)
        #expect(graph.texts.contains("December 2026"))
        tap("1", in: graph)
        #expect(selection.value == Self.date(2026, 12, 1))
    }

    @Test func datePickerKeepsToItsRange() {
        let selection = Box(Self.date(2026, 11, 13))
        let graph = layout(
            picker(DatePicker("Due", selection: selection.binding, in: Self.date(2026, 11, 10, 0, 0)..., displayedComponents: .date).datePickerStyle(.graphical)),
            width: 400, height: 400
        )
        tap("5", in: graph)
        #expect(selection.value == Self.date(2026, 11, 13))
        tap("10", in: graph)
        #expect(selection.value == Self.date(2026, 11, 10))
    }

    @Test func calendarWeeksStartOnTheFirstWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.utc
        calendar.firstWeekday = 1
        // November 2026 starts on a Sunday.
        let days = _CalendarView.days(in: Self.date(2026, 11, 1, 0, 0), calendar: calendar)
        #expect(days.first! != nil)
        #expect(days.count == 35)
        calendar.firstWeekday = 2
        let mondayFirst = _CalendarView.days(in: Self.date(2026, 11, 1, 0, 0), calendar: calendar)
        #expect(mondayFirst.prefix(6).allSatisfy { $0 == nil })
    }

    @Test func colorPickerEditsHueSaturationBrightness() {
        let hsb = HSBColor(Color.Resolved(red: 1, green: 0.5, blue: 0))
        #expect(abs(hsb.hue - 30.0 / 360) < 0.0001)
        #expect(hsb.saturation == 1 && hsb.brightness == 1)
        let selection = Box(Color.red)
        let graph = layout(ColorPicker("Tint", selection: selection.binding), width: 400, height: 400)
        tap("Color", in: graph)
        #expect(graph.texts.contains("Hue"))
        #expect(graph.texts.contains("Opacity"))
    }
}
