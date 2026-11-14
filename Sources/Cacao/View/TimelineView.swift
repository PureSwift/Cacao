//
//  TimelineView.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation

// MARK: - Schedules

/// A type that provides a sequence of dates for use as a schedule.
public protocol TimelineSchedule {

    /// The sequence of dates within a schedule.
    associatedtype Entries: Sequence where Entries.Element == Date

    /// Provides a sequence of dates starting around a given date.
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries
}

/// A mode of operation for timeline schedule updates.
public enum TimelineScheduleMode: Sendable {

    /// A mode that produces schedule updates at the schedule's natural cadence.
    case normal

    /// A mode that produces schedule updates at a reduced rate.
    case lowFrequency
}

/// A pattern for updating a timeline view as quickly as possible, for
/// animations.
public struct AnimationTimelineSchedule: TimelineSchedule, Sendable {

    let minimumInterval: Double?

    let paused: Bool

    /// Create a pausable schedule that updates as often as possible, but no
    /// more often than the minimum interval.
    public init(minimumInterval: Double? = nil, paused: Bool = false) {
        self.minimumInterval = minimumInterval
        self.paused = paused
    }

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(start: startDate, interval: paused ? nil : max(minimumInterval ?? 1.0 / 120, 1.0 / 120))
    }

    /// The sequence of dates within the schedule.
    public struct Entries: Sequence, IteratorProtocol, Sendable {

        var upcoming: Date

        let interval: Double?

        init(start: Date, interval: Double?) {
            self.upcoming = start
            self.interval = interval
        }

        public mutating func next() -> Date? {
            guard let interval else { return nil }
            defer { upcoming = upcoming.addingTimeInterval(interval) }
            return upcoming
        }
    }
}

/// A schedule for updating a timeline view at regular intervals.
public struct PeriodicTimelineSchedule: TimelineSchedule, Sendable {

    let startDate: Date

    let interval: TimeInterval

    /// Creates a periodic update schedule.
    public init(from startDate: Date, by interval: TimeInterval) {
        self.startDate = startDate
        self.interval = max(interval, 0.001)
    }

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        // The last entry at or before the start, then every interval.
        let elapsed = startDate.timeIntervalSince(self.startDate)
        let first = elapsed > 0
            ? self.startDate.addingTimeInterval((elapsed / interval).rounded(.down) * interval)
            : self.startDate
        return Entries(upcoming: first, interval: interval)
    }

    /// The sequence of dates in periodic schedule.
    public struct Entries: Sequence, IteratorProtocol, Sendable {

        var upcoming: Date

        let interval: TimeInterval

        public mutating func next() -> Date? {
            defer { upcoming = upcoming.addingTimeInterval(interval) }
            return upcoming
        }
    }
}

/// A schedule for updating a timeline view at the start of every minute.
public struct EveryMinuteTimelineSchedule: TimelineSchedule, Sendable {

    public init() { }

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> PeriodicTimelineSchedule.Entries {
        let seconds = startDate.timeIntervalSinceReferenceDate
        let minute = Date(timeIntervalSinceReferenceDate: (seconds / 60).rounded(.down) * 60)
        return PeriodicTimelineSchedule(from: minute, by: 60).entries(from: startDate, mode: mode)
    }
}

/// A schedule for updating a timeline view at explicit points in time.
public struct ExplicitTimelineSchedule<Entries: Sequence>: TimelineSchedule where Entries.Element == Date {

    let dates: Entries

    /// Creates a schedule composed of an explicit sequence of dates.
    public init(_ dates: Entries) {
        self.dates = dates
    }

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        dates
    }
}

extension TimelineSchedule where Self == AnimationTimelineSchedule {

    /// A pausable schedule of dates updating at a frequency no more quickly
    /// than the provided interval.
    public static func animation(minimumInterval: Double? = nil, paused: Bool = false) -> AnimationTimelineSchedule {
        AnimationTimelineSchedule(minimumInterval: minimumInterval, paused: paused)
    }

    /// A schedule for updating a timeline view as often as possible.
    public static var animation: AnimationTimelineSchedule {
        AnimationTimelineSchedule()
    }
}

extension TimelineSchedule where Self == PeriodicTimelineSchedule {

    /// A schedule for updating a timeline view at regular intervals.
    public static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule {
        PeriodicTimelineSchedule(from: startDate, by: interval)
    }
}

extension TimelineSchedule where Self == EveryMinuteTimelineSchedule {

    /// A schedule for updating a timeline view at the start of every minute.
    public static var everyMinute: EveryMinuteTimelineSchedule {
        EveryMinuteTimelineSchedule()
    }
}

extension TimelineSchedule {

    /// A schedule for updating a timeline view at explicit points in time.
    public static func explicit<S: Sequence>(_ dates: S) -> ExplicitTimelineSchedule<S> where Self == ExplicitTimelineSchedule<S> {
        ExplicitTimelineSchedule(dates)
    }
}

// MARK: - TimelineView

/// Information passed to a timeline view's content callback.
public struct TimelineViewDefaultContext {

    /// A rate at which timeline views can receive updates.
    public enum Cadence: Comparable, Sendable {
        case live
        case seconds
        case minutes
    }

    /// The date from the schedule that triggered the current view update.
    public let date: Date

    /// The rate at which the timeline updates the view.
    public let cadence: Cadence
}

/// A view that updates according to a schedule that you provide.
public struct TimelineView<Schedule: TimelineSchedule, Content: View>: View, PrimitiveView {

    /// Information passed to a timeline view's content callback.
    public typealias Context = TimelineViewDefaultContext

    let schedule: Schedule

    let content: (Context) -> Content

    /// Creates a new timeline view that uses the given schedule.
    public init(_ schedule: Schedule, @ViewBuilder content: @escaping (Context) -> Content) {
        self.schedule = schedule
        self.content = content
    }

    public typealias Body = Never

    func resolve(in context: ResolveContext) -> Resolution {
        let graph = context.graph
        let now = graph.currentDate()
        // The latest entry at or before now, and the next one after it.
        var current: Date?
        var next: Date?
        var count = 0
        for date in schedule.entries(from: now, mode: .normal) {
            count += 1
            if date <= now {
                current = date
            } else {
                next = date
                break
            }
            if count > 10_000 { break }
        }
        let cadence: TimelineViewDefaultContext.Cadence
        if let current, let next {
            let interval = next.timeIntervalSince(current)
            cadence = interval < 1 ? .live : interval < 60 ? .seconds : .minutes
        } else {
            cadence = .live
        }
        graph.scheduleWakeup(context.node, after: next.map { $0.timeIntervalSince(now) })
        let body = content(Context(date: current ?? now, cadence: cadence))
        return Resolution(children: [ChildView(key: 0, view: body)])
    }
}

// MARK: - Graph

extension ViewGraph {

    /// The current date, for timelines.
    func currentDate() -> Date {
        dateProvider()
    }

    /// Updates a node again after a delay in seconds, or stops updating it.
    func scheduleWakeup(_ node: ViewNode, after delay: TimeInterval?) {
        if let delay {
            wakeups[node.id] = (WeakNodeReference(node), time + max(delay, 0))
        } else {
            wakeups[node.id] = nil
        }
    }

    /// Invalidates nodes whose wakeup time has come.
    func fireWakeups() {
        guard !wakeups.isEmpty else { return }
        for (id, wakeup) in wakeups where wakeup.time <= time + 0.001 {
            wakeups[id] = nil
            if let node = wakeup.node.node, node.isAttached {
                node.invalidate()
            }
        }
    }

    /// The next time a timeline updates, for the host to wake up.
    package var nextWakeup: Double? {
        wakeups.values.compactMap { $0.node.node?.isAttached == true ? $0.time : nil }.min()
    }

    /// Whether a timeline updates every frame.
    var hasFrameWakeups: Bool {
        guard let next = nextWakeup else { return false }
        return next - time < 0.05
    }
}
