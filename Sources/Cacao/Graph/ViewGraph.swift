//
//  ViewGraph.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
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

    /// The gestures of the interaction in progress.
    var gestureSession: GestureSession?

    /// Timelines waiting to update, by node, with the time they update at.
    var wakeups: [Int: (node: WeakNodeReference, time: Double)] = [:]

    /// The views the pointer hovers over.
    var hoveredNodes: [Int: WeakNodeReference] = [:]

    /// A drag of a view's value in progress.
    var dragSession: DragSession?

    /// A drag from the system over the window in progress.
    var systemDragSession: DragSession?

    /// The window's insets that content stays inside of, like a notch's.
    package var safeAreaInsets = EdgeInsets()

    /// Actions to run once the current layout pass has placed every view.
    var afterLayoutActions: [() -> Void] = []

    /// Checks to run after each update, by node, like preference readers
    /// checking the values they read.
    var updateObservers: [Int: (node: WeakNodeReference, check: () -> Void)] = [:]

    /// Scroll views moving to a position programmatically.
    var scrollAnimations: [ObjectIdentifier: (state: ScrollState, animation: PropertyAnimation)] = [:]

    /// The current date, which tests replace.
    package var dateProvider: () -> Date = { Date() }

    let focusedNodeReference = WeakNodeReference()

    /// The external content a mouse press is being delivered to, and the
    /// button that started it.
    var externalPress: (node: WeakNodeReference, button: ExternalInput.Button)?

    /// The external content each finger came down on.
    var externalTouches: [UInt64: WeakNodeReference] = [:]

    /// The external content under the pointer.
    let externalHovered = WeakNodeReference()

    // MARK: Animation state

    /// The time animations are evaluated at, in seconds, from the host's clock.
    package var time: Double = 0

    /// The transaction of state changes waiting for the next update.
    var pendingTransaction: Transaction?

    /// The transaction of the update in progress, as modifiers change it.
    var currentTransaction = Transaction()

    /// The transaction of the last update, for layout changes it causes.
    var baseTransaction = Transaction()

    /// The update whose changes the last layout animated.
    var committedGeneration = -1

    /// Counts updates, to tell what changed in the last one.
    private(set) var updateGeneration = 0

    var nodeAnimations: [Int: NodeAnimations] = [:]

    /// Removed views transitioning out, by their parent node.
    var ghosts: [Int: [Ghost]] = [:]

    /// The frames of matched geometry groups from the last layout.
    var matchedFrames: [AnyHashable: (frame: CGRect, node: Int)] = [:]

    /// Animatable views mid-animation, re-resolved each frame.
    var animatedViewNodes: [Int: WeakNodeReference] = [:]

    /// The lazy stacks in the graph, which create rows as they scroll.
    var lazyStacks: [WeakNodeReference] = []

    /// The system clipboard, provided by the host.
    package var clipboard: Clipboard?

    /// Shows the system's share picker, where the host has one; returns
    /// whether it did. Share links update when it's set.
    package var share: ((ShareRequest) -> Bool)? {
        didSet {
            for reference in shareLinks.values {
                reference.node?.invalidate()
            }
        }
    }

    /// The share links in the graph, by node.
    var shareLinks: [Int: WeakNodeReference] = [:]

    /// The help text shown as a tooltip, and where the pointer rested.
    var tooltip: (text: String, location: CGPoint)?

    /// Help text under the pointer, to show as a tooltip once it rests.
    var pendingTooltip: (text: String, location: CGPoint, time: Double)?

    /// The pointer style of the view under the pointer, which the host
    /// shows; `nil` for the default.
    package internal(set) var pointerStyle: PointerStyle?

    /// The host's open and save dialogs.
    package var fileDialogs: FileDialogs?

    /// The title the window's content asks for, like a document's name;
    /// the host shows it.
    package internal(set) var windowTitle: String?

    /// The document the window shows, if it's a document window.
    var documentController: DocumentController?

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

    /// Views presented above the content, like menus and sheets.
    var presentations: [Presentation] = []

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
            view: _GraphRoot(content: rootContent),
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
        guard !dirtyNodes.isEmpty else { return }
        updateGeneration += 1
        currentTransaction = pendingTransaction ?? Transaction()
        pendingTransaction = nil
        baseTransaction = currentTransaction
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
        for (node, transaction) in invalidations.drain() where node.isAttached {
            record(transaction)
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
        for (id, observer) in updateObservers {
            if observer.node.node?.isAttached == true {
                observer.check()
            } else {
                updateObservers[id] = nil
            }
        }
    }

    /// Runs an action after the current layout pass places every view.
    func afterLayout(_ action: @escaping () -> Void) {
        afterLayoutActions.append(action)
    }

    /// Runs a check after every update, for as long as the node is in the
    /// graph or until the node registers another.
    func observeUpdates(of node: ViewNode, _ check: @escaping () -> Void) {
        updateObservers[node.id] = (WeakNodeReference(node), check)
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
        nodeAnimations[node.id] = nil
        animatedViewNodes[node.id] = nil
        // What a view presented goes away with it.
        if presentations.contains(where: { $0.owner == AnyHashable(node.id) }) {
            removePresentation(owner: AnyHashable(node.id))
        }
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
        needsDisplay = true
        // Layout can invalidate views, like geometry readers given a new
        // size: update them and lay out again, in the same transaction.
        let transaction = baseTransaction
        var passes = 0
        while true {
            layoutGeneration += 1
            statistics.layouts += 1
            root.place(at: CGPoint(x: 0, y: 0), proposal: ProposedViewSize(size))
            var sources: [AnyHashable: (size: CGSize, point: CGPoint)] = [:]
            var followers: [(ViewNode, MatchedGeometry)] = []
            root.forEachNode { node in
                node.isLayoutValid = true
                if let geometry = node.attributes.matchedGeometry {
                    if geometry.isSource {
                        let frame = node.subtreeFrame
                        if !frame.isNull {
                            sources[geometry.key] = (frame.size, geometry.anchorPoint(in: frame))
                        }
                    } else {
                        followers.append((node, geometry))
                    }
                }
            }
            placeMatchedGeometry(followers, sources: sources)
            let actions = afterLayoutActions
            afterLayoutActions.removeAll()
            for action in actions {
                action()
            }
            drainInvalidations()
            passes += 1
            guard !dirtyNodes.isEmpty, passes < 4 else { break }
            if pendingTransaction == nil {
                pendingTransaction = transaction
            }
            update()
        }
        commitAnimations()
    }

    /// Places views that aren't the source of their matched geometry group
    /// in the source's frame: proposed its size and lined up at the anchor.
    private func placeMatchedGeometry(_ followers: [(ViewNode, MatchedGeometry)], sources: [AnyHashable: (size: CGSize, point: CGPoint)]) {
        for (node, geometry) in followers {
            guard let source = sources[geometry.key],
                  let proxy = LayoutProxy.combining(node.layoutChildren) else {
                continue
            }
            let current = node.subtreeFrame
            let proposal = geometry.properties.contains(.size)
                ? ProposedViewSize(source.size)
                : ProposedViewSize(current.size)
            let size = proxy.size(in: proposal)
            let frame = geometry.frame(at: CGRect(origin: current.origin, size: size), matching: size, point: source.point)
            proxy.place(at: frame.origin, proposal: proposal)
            node.forEachNode { $0.isLayoutValid = true }
        }
    }

    // MARK: Queries

    /// The frames of every view with an accessibility identifier, from the
    /// last layout.
    package func identifiedFrames() -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        root.forEachDisplayedNode { node in
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
        root.forEachDisplayedNode { node in
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

    /// Visits this node and the descendants it displays, depth first,
    /// skipping views that don't show, like `ViewThatFits`' other candidates.
    func forEachDisplayedNode(_ body: (ViewNode) -> Void) {
        body(self)
        for child in orderedChildren {
            child.forEachDisplayedNode(body)
        }
    }

    /// Whether the node is still part of its graph's tree.
    var isAttached: Bool {
        parent != nil || graph.root === self
    }

}
