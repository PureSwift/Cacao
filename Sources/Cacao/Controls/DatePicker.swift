//
//  DatePicker.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Locale environment

private struct LocaleKey: EnvironmentKey {
    static var defaultValue: Locale { .current }
}

private struct CalendarKey: EnvironmentKey {
    static var defaultValue: Calendar { .current }
}

private struct TimeZoneKey: EnvironmentKey {
    static var defaultValue: TimeZone { .current }
}

extension EnvironmentValues {

    /// The current locale that views should use.
    public var locale: Locale {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }

    /// The current calendar that views should use when handling dates.
    public var calendar: Calendar {
        get { self[CalendarKey.self] }
        set { self[CalendarKey.self] = newValue }
    }

    /// The current time zone that views should use when handling dates.
    public var timeZone: TimeZone {
        get { self[TimeZoneKey.self] }
        set { self[TimeZoneKey.self] = newValue }
    }

    /// The calendar in the environment's time zone.
    internal var zonedCalendar: Calendar {
        var calendar = self.calendar
        calendar.timeZone = timeZone
        calendar.locale = locale
        return calendar
    }
}

// MARK: - DatePicker

/// The components of a date that a date picker shows and edits.
public struct DatePickerComponents: OptionSet, Sendable {

    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Displays hour and minute components.
    public static let hourAndMinute = DatePickerComponents(rawValue: 1 << 0)

    /// Displays day, month, and year components.
    public static let date = DatePickerComponents(rawValue: 1 << 1)
}

/// A control for selecting an absolute date.
public struct DatePicker<Label: View>: View {

    public typealias Components = DatePickerComponents

    internal let selection: Binding<Date>

    internal let range: ClosedRange<Date>

    internal let components: Components

    internal let label: Label

    @Environment(\.datePickerStyle) private var style

    @Environment(\.labelsHidden) private var labelsHidden

    @Environment(\.self) private var environment

    @State private var editsDate = false

    @State private var editsTime = false

    public var body: some View {
        if style == .graphical {
            VStack(alignment: .leading, spacing: 8) {
                if !labelsHidden {
                    label
                }
                if components.contains(.date) {
                    _CalendarView(selection: selection, range: range)
                }
                if components.contains(.hourAndMinute) {
                    _TimeEditor(selection: selection, range: range)
                }
            }
        } else {
            HStack(spacing: 8) {
                if !labelsHidden {
                    label
                    Spacer(minLength: 8)
                }
                if components.contains(.date) {
                    _FieldButton(title: Self.format(selection.wrappedValue, date: .medium, time: .none, in: environment)) {
                        editsDate = true
                    }
                    .popover(isPresented: $editsDate) {
                        _CalendarView(selection: selection, range: range).padding(12)
                    }
                }
                if components.contains(.hourAndMinute) {
                    _FieldButton(title: Self.format(selection.wrappedValue, date: .none, time: .short, in: environment)) {
                        editsTime = true
                    }
                    .popover(isPresented: $editsTime) {
                        _TimeEditor(selection: selection, range: range).padding(12)
                    }
                }
            }
        }
    }

    /// A date formatted in the environment's locale, calendar and time zone.
    internal static func format(_ date: Date, date dateStyle: DateFormatter.Style, time timeStyle: DateFormatter.Style, in environment: EnvironmentValues) -> String {
        let formatter = DateFormatter()
        formatter.locale = environment.locale
        formatter.calendar = environment.zonedCalendar
        formatter.timeZone = environment.timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}

extension DatePicker {

    /// Creates an instance that selects a date.
    public init(
        selection: Binding<Date>,
        displayedComponents: Components = [.hourAndMinute, .date],
        @ViewBuilder label: () -> Label
    ) {
        self.init(pickerSelection: selection, range: Date.distantPast...Date.distantFuture, components: displayedComponents, label: label())
    }

    /// Creates an instance that selects a date in a closed range.
    public init(
        selection: Binding<Date>,
        in range: ClosedRange<Date>,
        displayedComponents: Components = [.hourAndMinute, .date],
        @ViewBuilder label: () -> Label
    ) {
        self.init(pickerSelection: selection, range: range, components: displayedComponents, label: label())
    }

    /// Creates an instance that selects a date on or after a start date.
    public init(
        selection: Binding<Date>,
        in range: PartialRangeFrom<Date>,
        displayedComponents: Components = [.hourAndMinute, .date],
        @ViewBuilder label: () -> Label
    ) {
        self.init(pickerSelection: selection, range: range.lowerBound...Date.distantFuture, components: displayedComponents, label: label())
    }

    /// Creates an instance that selects a date on or before an end date.
    public init(
        selection: Binding<Date>,
        in range: PartialRangeThrough<Date>,
        displayedComponents: Components = [.hourAndMinute, .date],
        @ViewBuilder label: () -> Label
    ) {
        self.init(pickerSelection: selection, range: Date.distantPast...range.upperBound, components: displayedComponents, label: label())
    }

    internal init(pickerSelection selection: Binding<Date>, range: ClosedRange<Date>, components: Components, label: Label) {
        self.selection = selection
        self.range = range
        self.components = components
        self.label = label
    }
}

extension DatePicker where Label == Text {

    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(pickerSelection: selection, range: Date.distantPast...Date.distantFuture, components: displayedComponents, label: Text(titleKey))
    }

    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(pickerSelection: selection, range: range, components: displayedComponents, label: Text(titleKey))
    }

    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(pickerSelection: selection, range: range.lowerBound...Date.distantFuture, components: displayedComponents, label: Text(titleKey))
    }

    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(pickerSelection: selection, range: Date.distantPast...range.upperBound, components: displayedComponents, label: Text(titleKey))
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(pickerSelection: selection, range: Date.distantPast...Date.distantFuture, components: displayedComponents, label: Text(title))
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(pickerSelection: selection, range: range, components: displayedComponents, label: Text(title))
    }
}

/// A rounded field that opens an editor, for date and color pickers.
internal struct _FieldButton: View {

    let title: String

    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.controlFill))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar

/// A month of days to choose from, with buttons for the previous and next
/// months.
internal struct _CalendarView: View {

    let selection: Binding<Date>

    let range: ClosedRange<Date>

    @Environment(\.self) private var environment

    /// The first day of the month shown, when it's not the selection's.
    @State private var shownMonth: Date?

    var body: some View {
        let calendar = environment.zonedCalendar
        let month = shownMonth ?? Self.startOfMonth(selection.wrappedValue, calendar: calendar)
        let days = Self.days(in: month, calendar: calendar)
        let weekdays = Self.weekdaySymbols(calendar: calendar)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.monthTitle(month, in: environment)).font(.headline)
                Spacer()
                Button {
                    shownMonth = calendar.date(byAdding: .month, value: -1, to: month)
                } label: {
                    _ChevronShape(pointsDown: false, pointsLeft: true).stroke(Color.accentColor, lineWidth: 2).frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous Month")
                Button {
                    shownMonth = calendar.date(byAdding: .month, value: 1, to: month)
                } label: {
                    _ChevronShape(pointsDown: false).stroke(Color.accentColor, lineWidth: 2).frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next Month")
            }
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    ForEach(0..<7, id: \.self) { column in
                        Text(weekdays[column]).font(.caption2).foregroundStyle(.secondary).frame(width: 28)
                    }
                }
                ForEach(0..<(days.count / 7), id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { column in
                            dayCell(days[row * 7 + column], month: month, calendar: calendar)
                        }
                    }
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func dayCell(_ day: Date?, month: Date, calendar: Calendar) -> some View {
        if let day {
            let isSelected = calendar.isDate(day, inSameDayAs: selection.wrappedValue)
            // Days with any time in the range.
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let isEnabled = start <= range.upperBound && end > range.lowerBound
            let number = calendar.component(.day, from: day)
            Button {
                selection.wrappedValue = Self.date(day, keepingTimeOf: selection.wrappedValue, calendar: calendar, clampedTo: range)
                shownMonth = nil
            } label: {
                Text("\(number)")
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(width: 28, height: 24)
                    .background(Circle().fill(isSelected ? Color.accentColor : Color.clear))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.3)
            .accessibilityLabel("\(number)")
        } else {
            Color.clear.frame(width: 28, height: 24)
        }
    }

    static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    /// The month's days in weeks of seven, with nil before the first day
    /// and after the last.
    static func days(in month: Date, calendar: Calendar) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            days.append(calendar.date(byAdding: .day, value: offset, to: month))
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    static func monthTitle(_ month: Date, in environment: EnvironmentValues) -> String {
        let formatter = DateFormatter()
        formatter.locale = environment.locale
        formatter.calendar = environment.zonedCalendar
        formatter.timeZone = environment.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: month)
    }

    /// A day at the time of day of another date, kept within a range.
    static func date(_ day: Date, keepingTimeOf time: Date, calendar: Calendar, clampedTo range: ClosedRange<Date>) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let clock = calendar.dateComponents([.hour, .minute, .second], from: time)
        components.hour = clock.hour
        components.minute = clock.minute
        components.second = clock.second
        let date = calendar.date(from: components) ?? day
        return min(max(date, range.lowerBound), range.upperBound)
    }
}

// MARK: - Time

/// Steppers for the hour and minute of a date.
internal struct _TimeEditor: View {

    let selection: Binding<Date>

    let range: ClosedRange<Date>

    @Environment(\.self) private var environment

    var body: some View {
        let calendar = environment.zonedCalendar
        let date = selection.wrappedValue
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        HStack(spacing: 12) {
            Stepper {
                Text(Self.twoDigits(hour)).monospacedDigit()
            } onIncrement: {
                set(\.hour, (hour + 1) % 24)
            } onDecrement: {
                set(\.hour, (hour + 23) % 24)
            }
            .accessibilityLabel("Hour")
            Text(":")
            Stepper {
                Text(Self.twoDigits(minute)).monospacedDigit()
            } onIncrement: {
                set(\.minute, (minute + 1) % 60)
            } onDecrement: {
                set(\.minute, (minute + 59) % 60)
            }
            .accessibilityLabel("Minute")
        }
        .fixedSize()
    }

    private func set(_ component: WritableKeyPath<DateComponents, Int?>, _ value: Int) {
        let calendar = environment.zonedCalendar
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: selection.wrappedValue)
        components[keyPath: component] = value
        if let date = calendar.date(from: components) {
            selection.wrappedValue = min(max(date, range.lowerBound), range.upperBound)
        }
    }

    static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

// MARK: - Styles

/// The styles of date pickers.
public struct DatePickerStyleKind: Equatable, Sendable {
    internal let name: String
    static let compact = DatePickerStyleKind(name: "compact")
    static let graphical = DatePickerStyleKind(name: "graphical")
}

/// A date picker style.
public protocol DatePickerStyle {
    var _kind: DatePickerStyleKind { get }
}

/// The default date picker style: compact.
public struct DefaultDatePickerStyle: DatePickerStyle {
    public init() { }
    public var _kind: DatePickerStyleKind { .compact }
}

/// A date picker style that displays the components in a compact, textual
/// format, with a calendar in a popover.
public struct CompactDatePickerStyle: DatePickerStyle {
    public init() { }
    public var _kind: DatePickerStyleKind { .compact }
}

/// A date picker style that displays an interactive calendar or clock.
public struct GraphicalDatePickerStyle: DatePickerStyle {
    public init() { }
    public var _kind: DatePickerStyleKind { .graphical }
}

/// A date picker style that displays the components in editable fields;
/// in Cacao, the compact style.
public struct FieldDatePickerStyle: DatePickerStyle {
    public init() { }
    public var _kind: DatePickerStyleKind { .compact }
}

/// A date picker style that displays the components in editable fields
/// with a stepper; in Cacao, the compact style.
public struct StepperFieldDatePickerStyle: DatePickerStyle {
    public init() { }
    public var _kind: DatePickerStyleKind { .compact }
}

/// A date picker style that displays each component as columns in a
/// scrollable wheel; in Cacao, the graphical style.
public struct WheelDatePickerStyle: DatePickerStyle {
    public init() { }
    public var _kind: DatePickerStyleKind { .graphical }
}

extension DatePickerStyle where Self == DefaultDatePickerStyle {
    public static var automatic: DefaultDatePickerStyle { DefaultDatePickerStyle() }
}

extension DatePickerStyle where Self == CompactDatePickerStyle {
    public static var compact: CompactDatePickerStyle { CompactDatePickerStyle() }
}

extension DatePickerStyle where Self == GraphicalDatePickerStyle {
    public static var graphical: GraphicalDatePickerStyle { GraphicalDatePickerStyle() }
}

extension DatePickerStyle where Self == FieldDatePickerStyle {
    public static var field: FieldDatePickerStyle { FieldDatePickerStyle() }
}

extension DatePickerStyle where Self == StepperFieldDatePickerStyle {
    public static var stepperField: StepperFieldDatePickerStyle { StepperFieldDatePickerStyle() }
}

extension DatePickerStyle where Self == WheelDatePickerStyle {
    public static var wheel: WheelDatePickerStyle { WheelDatePickerStyle() }
}

private struct DatePickerStyleKey: EnvironmentKey {
    static let defaultValue = DatePickerStyleKind.compact
}

extension EnvironmentValues {

    internal var datePickerStyle: DatePickerStyleKind {
        get { self[DatePickerStyleKey.self] }
        set { self[DatePickerStyleKey.self] = newValue }
    }
}

extension View {

    /// Sets the style for date pickers within this view.
    public func datePickerStyle<S: DatePickerStyle>(_ style: S) -> some View {
        environment(\.datePickerStyle, style._kind)
    }
}
