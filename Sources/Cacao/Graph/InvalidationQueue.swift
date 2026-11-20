//
//  InvalidationQueue.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import CacaoRender
import Foundation

/// Nodes invalidated by state writes and observation changes, which may
/// happen on any thread, waiting for the graph to mark them dirty.
///
/// The graph drains the queue on the main actor before it reports whether
/// it needs an update and before it updates, so a write is seen by the next
/// update whichever thread it came from. The first enqueued node also
/// schedules a drain on the main actor, to tell the host.
internal final class InvalidationQueue: @unchecked Sendable {

    private let lock = NSLock()

    private var nodes: [WeakNode] = []

    private struct WeakNode {
        weak var node: ViewNode?
        var transaction: Transaction?
    }

    /// The graph to wake, read and written only on the main actor.
    nonisolated(unsafe) weak var graph: ViewGraph?

    func enqueue(_ node: ViewNode?, transaction: Transaction? = nil) {
        guard let node else { return }
        lock.lock()
        let wasEmpty = nodes.isEmpty
        nodes.append(WeakNode(node: node, transaction: transaction))
        lock.unlock()
        guard wasEmpty else { return }
        let queue = UncheckedSendable(self)
        Task { @MainActor in
            queue.value.graph?.drainInvalidations()
        }
    }

    /// Removes and returns the queued nodes that still exist, with the
    /// transactions they were invalidated in.
    func drain() -> [(node: ViewNode, transaction: Transaction?)] {
        lock.lock()
        let drained = nodes
        nodes.removeAll()
        lock.unlock()
        return drained.compactMap { entry in entry.node.map { ($0, entry.transaction) } }
    }
}
