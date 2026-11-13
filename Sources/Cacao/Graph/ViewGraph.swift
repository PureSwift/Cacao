//
//  ViewGraph.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The retained tree of a root view: evaluation, layout and the display list.
///
/// A host owns one graph per window. It sets `onNeedsUpdate` to schedule
/// work, then calls `update()`, `layout(in:)` and `displayList()` once per
/// frame that needs them.
@MainActor
package final class ViewGraph {

    /// Measures and lays out text.
    package let textEngine: any TextEngine

    /// The environment given to the root view.
    package var environment: EnvironmentValues {
        didSet { root.update(view: root.view, environment: environment); root.invalidate() }
    }

    /// Called when the graph needs an update, once until the next `update()`.
    package var onNeedsUpdate: (() -> Void)?

    /// Whether some node must be resolved again.
    package var needsUpdate: Bool {
        drainInvalidations()
        return !dirtyNodes.isEmpty
    }

    /// Nodes invalidated by state writes and observation, from any thread.
    let invalidations = InvalidationQueue()

    /// The size of the last layout.
    package private(set) var size: CGSize = .zero

    private(set) var root: ViewNode!

    private var nextNodeID = 0

    private var dirtyNodes: [ViewNode] = []

    private var appearedNodes: [ViewNode] = []

    private var disappearActions: [() -> Void] = []

    private var deferredActions: [() -> Void] = []

    private var lastPreferenceValues: [Int: Any] = [:]

    private(set) var layoutGeneration = 0

    /// The tap gesture node a press started on.
    weak var activeTap: ViewNode?

    var activeTapIsInside = false

    /// The drag gesture node a press started on, and where the press started.
    weak var activeDrag: ViewNode?

    var activeDragStart = CGPoint(x: 0, y: 0)

    var activeDragFrame = CGRect.zero

    let focusedNodeReference = WeakNodeReference()

    /// The lazy stacks in the graph, which create rows as they scroll.
    var lazyStacks: [WeakNodeReference] = []

    /// The system clipboard, provided by the host.
    package var clipboard: Clipboard?

    /// Whether the drawing changed without an update, as when scrolling.
    package internal(set) var needsDisplay = true

    /// Called when the drawing changes without an update.
    package var onNeedsDisplay: (() -> Void)?

    /// Counts of the graph's work, for tests and diagnostics.
    package struct Statistics: Equatable, Sendable {

        /// Nodes resolved: bodies evaluated or primitives described.
        package var resolves = 0

        /// Layout passes.
        package var layouts = 0
    }

    package internal(set) var statistics = Statistics()

    /// Marks the drawing as changed.
    package func setNeedsDisplay() {
        guard !needsDisplay else { return }
        needsDisplay = true
        onNeedsDisplay?()
    }

    /// The app's root view.
    private(set) var rootContent: AnyView

    /// Views presented above the content, like menus.
    var popups: [Popup] = []

    var nextPopupID = 0

    /// Creates a graph for a root view and resolves it.
    package init<Root: View>(
        rootView: Root,
        environment: EnvironmentValues = EnvironmentValues(),
        textEngine: any TextEngine = FixedTextEngine()
    ) {
        self.textEngine = textEngine
        self.environment = environment
        self.rootContent = AnyView(rootView)
        invalidations.graph = self
        self.root = ViewNode(
            graph: self,
            parent: nil,
            key: AnyHashable(0),
            view: _GraphRoot(content: rootContent, popups: []),
            environment: environment
        )
        appearedNodes.append(root)
        root.resolve()
        finishUpdate()
    }

    /// Replaces the root view. A view of the same type keeps its state.
    package func setRootView<Root: View>(_ rootView: Root) {
        rootContent = AnyView(rootView)
        updateRoot()
    }

    // MARK: Updating

    /// Resolves the nodes invalidated since the last update, outermost first,
    /// then runs appearance actions and preference observers, repeating while
    /// they invalidate more nodes.
    package func update() {
        drainInvalidations()
        var passes = 0
        while !dirtyNodes.isEmpty, passes < 16 {
            passes += 1
            let nodes = dirtyNodes.sorted { $0.depth < $1.depth }
            dirtyNodes.removeAll()
            for node in nodes where node.isDirty && node.isAttached {
                node.resolve()
            }
            finishUpdate()
            applyFocusRequests()
            drainInvalidations()
        }
    }

    /// Marks the nodes invalidated since the last drain dirty.
    func drainInvalidations() {
        for node in invalidations.drain() where node.isAttached {
            node.invalidate()
        }
    }

    /// Runs an action after the current update, outside of resolving.
    func deferAction(_ action: @escaping () -> Void) {
        deferredActions.append(action)
    }

    private func finishUpdate() {
        let deferred = deferredActions
        deferredActions.removeAll()
        for action in deferred {
            action()
        }
        for action in disappearActions {
            action()
        }
        disappearActions.removeAll()
        let appeared = appearedNodes
        appearedNodes.removeAll()
        for node in appeared where node.isAttached {
            node.attributes.onAppear?()
        }
        notifyPreferenceObservers()
    }

    func nodeDidInvalidate(_ node: ViewNode) {
        let wasClean = dirtyNodes.isEmpty
        dirtyNodes.append(node)
        if wasClean {
            onNeedsUpdate?()
        }
    }

    func nodeDidAppear(_ node: ViewNode) {
        appearedNodes.append(node)
    }

    func nodeDidDisappear(_ node: ViewNode) {
        if let action = node.attributes.onDisappear {
            disappearActions.append(action)
        }
        lastPreferenceValues[node.id] = nil
    }

    func makeNodeID() -> Int {
        nextNodeID += 1
        return nextNodeID
    }

    // MARK: Preferences

    private func notifyPreferenceObservers() {
        var actions: [() -> Void] = []
        root.forEachNode { node in
            guard let observer = node.attributes.preferenceObserver else {
                return
            }
            let value = observer.key.value(node.children)
            let last = lastPreferenceValues[node.id]
            if last == nil || !observer.isEqual(last!, value) {
                lastPreferenceValues[node.id] = value
                actions.append { observer.action(value) }
            }
        }
        for action in actions {
            action()
        }
    }

    // MARK: Layout

    /// Lays out the root view in a container of the given size, centering it
    /// as a window does, after updating any invalidated nodes.
    package func layout(in size: CGSize) {
        update()
        self.size = size
        layoutGeneration += 1
        statistics.layouts += 1
        needsDisplay = true
        root.place(at: CGPoint(x: 0, y: 0), proposal: ProposedViewSize(size))
        root.forEachNode { $0.isLayoutValid = true }
    }

    // MARK: Queries

    /// The frames of every view with an accessibility identifier, from the
    /// last layout.
    package func identifiedFrames() -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        root.forEachNode { node in
            guard let identifier = node.attributes.identifier, result[identifier] == nil else {
                return
            }
            result[identifier] = frame(forIdentifier: identifier)
        }
        return result
    }

    /// The frame of the view with the given accessibility identifier, in the
    /// root's coordinate space, from the last layout.
    package func frame(forIdentifier identifier: String) -> CGRect? {
        var result: CGRect?
        root.forEachNode { node in
            guard result == nil, node.attributes.identifier == identifier else {
                return
            }
            let frames = node.topLevelUnits.map(\.frame)
            result = frames.dropFirst().reduce(frames.first ?? .zero) { $0.union($1) }
        }
        return result
    }
}

extension ViewNode {

    /// Whether the node is still part of its graph's tree.
    var isAttached: Bool {
        parent != nil || graph.root === self
    }

}
