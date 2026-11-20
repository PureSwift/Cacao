//
//  ExternalSurface.swift
//  CacaoRender
//
//  Created by Alsey Coleman Miller on 11/19/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// Frames drawn outside the compositor (a GL or Metal drawable's, a web
/// view's, a video's), shown in a display list where the surface is placed.
///
/// A producer publishes frames from any thread; the compositor takes the
/// newest on the main thread, so this is where drawing crosses threads.
/// Frames come one of two ways:
///
/// - **Pixels**: each frame's pixels are copied in, and the compositor
///   updates one texture in place.
/// - **Shared buffers** (Linux): the producer exports a few GPU buffers as
///   dma-bufs once, then draws each frame into one the compositor isn't
///   using and publishes its index, with a fence the GPU signals when the
///   frame is finished. The compositor imports each buffer once and draws
///   the newest finished one, so no frame passes through the CPU. A
///   compositor that can't import the buffers says so (`buffersInUse` is
///   `nil`), and the producer publishes pixels instead.
public final class ExternalSurface: @unchecked Sendable {

    /// The order of a pixel's bytes: 8 bits each, premultiplied alpha.
    public enum PixelFormat: Hashable, Sendable {
        /// R, G, B, A, as OpenGL reads pixels back.
        case rgba
        /// B, G, R, A, as Metal's drawables have them.
        case bgra
    }

    /// Which row of a frame comes first.
    public enum RowOrder: Hashable, Sendable {
        case topFirst
        /// As OpenGL has them.
        case bottomFirst
    }

    /// A frame of pixels.
    public struct Frame: Sendable {

        public var pixels: Data

        public var width: Int

        public var height: Int

        public var bytesPerRow: Int

        public var format: PixelFormat

        public var rowOrder: RowOrder

        /// Whether every pixel is opaque, so the frame needs no blending.
        public var isOpaque: Bool

        /// Counts up with each frame published.
        public var generation: Int
    }

    /// A GPU buffer shared as a dma-buf.
    public struct Buffer: Sendable {

        /// The dma-buf's file descriptor.
        public var fileDescriptor: Int32

        public var width: Int32

        public var height: Int32

        public var stride: Int32

        public var offset: Int32

        /// The DRM format the buffer was exported with.
        public var fourCC: UInt32

        /// The DRM format modifier, or `Buffer.noModifier`.
        public var modifier: UInt64

        /// `DRM_FORMAT_MOD_INVALID`: exported without a modifier.
        public static let noModifier: UInt64 = 0x00ff_ffff_ffff_ffff

        public init(
            fileDescriptor: Int32,
            width: Int32,
            height: Int32,
            stride: Int32,
            offset: Int32 = 0,
            fourCC: UInt32,
            modifier: UInt64 = Buffer.noModifier
        ) {
            self.fileDescriptor = fileDescriptor
            self.width = width
            self.height = height
            self.stride = stride
            self.offset = offset
            self.fourCC = fourCC
            self.modifier = modifier
        }
    }

    /// The newest finished shared buffer, for the compositor.
    public struct TakenBuffer: Equatable, Sendable {

        /// The buffer's index.
        public var index: Int

        /// How many frames were published since the last one taken.
        public var frames: Int

        /// Whether a newer frame is still being drawn by the GPU.
        public var isWaiting: Bool

        public init(index: Int, frames: Int, isWaiting: Bool) {
            self.index = index
            self.frames = frames
            self.isWaiting = isWaiting
        }
    }

    /// The shared buffers, whose file descriptors the surface owns. Empty
    /// for a surface that only takes pixels.
    public let buffers: [Buffer]

    /// The row order of frames in the shared buffers.
    public let bufferRowOrder: RowOrder

    private let lock = NSLock()

    // Pixels.
    private var frame: Frame?
    private var generation = 0

    // Shared buffers.
    private var latest = -1
    private var showing = -1
    /// A frame the GPU is still drawing, and the fence it signals when
    /// done (owned here).
    private var pending: (index: Int, fence: Int32)?
    private var published = 0
    private var buffersFailed = false

    private var opaque = false
    private var unshown = false
    private var publishHandler: (@Sendable () -> Void)?

    /// Creates a surface that takes frames of pixels.
    public init() {
        self.buffers = []
        self.bufferRowOrder = .bottomFirst
    }

    /// Creates a surface whose frames are drawn into shared buffers. The
    /// buffers' file descriptors are duplicated, and remain the caller's.
    public init(buffers: [Buffer], rowOrder: RowOrder = .bottomFirst) {
        self.buffers = buffers.map { buffer in
            var buffer = buffer
            buffer.fileDescriptor = dup(buffer.fileDescriptor)
            return buffer
        }
        self.bufferRowOrder = rowOrder
    }

    deinit {
        if let pending { close(pending.fence) }
        for buffer in buffers where buffer.fileDescriptor >= 0 {
            close(buffer.fileDescriptor)
        }
    }

    private func locked<Result>(_ body: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: Producer

    /// Called, on the publishing thread, after each frame is published: a
    /// host wakes its loop here to draw the frame.
    public var onPublish: (@Sendable () -> Void)? {
        get { locked { publishHandler } }
        set { locked { publishHandler = newValue } }
    }

    /// Publishes a frame of pixels, which are copied.
    public func publish(
        pixels: UnsafeRawBufferPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int? = nil,
        format: PixelFormat = .rgba,
        rowOrder: RowOrder = .topFirst,
        isOpaque: Bool = false
    ) {
        let bytesPerRow = bytesPerRow ?? width * 4
        let count = min(pixels.count, bytesPerRow * height)
        let data = Data(bytes: pixels.baseAddress!, count: count)
        let handler: (@Sendable () -> Void)? = locked {
            generation &+= 1
            frame = Frame(
                pixels: data,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                format: format,
                rowOrder: rowOrder,
                isOpaque: isOpaque,
                generation: generation
            )
            opaque = isOpaque
            unshown = true
            return publishHandler
        }
        handler?()
    }

    /// Publishes a frame drawn into the shared buffer at `index`, finished
    /// when `fence` (a sync file, which the surface takes over) signals, or
    /// already if there is none. A frame still being drawn is passed over
    /// for it.
    public func publish(buffer index: Int, isOpaque: Bool = false, fence: Int32 = -1) {
        let handler: (@Sendable () -> Void)? = locked {
            if let old = pending { close(old.fence) }
            pending = nil
            if fence >= 0 {
                pending = (index, fence)
            } else {
                latest = index
            }
            published += 1
            opaque = isOpaque
            unshown = true
            return publishHandler
        }
        handler?()
    }

    /// The shared buffers the producer must not draw into (the one on
    /// screen, the newest finished, and the one still being drawn), as a
    /// mask of their indexes; `nil` once the compositor couldn't import the
    /// buffers, after which the producer publishes pixels.
    public var buffersInUse: Int? {
        locked {
            guard !buffersFailed else { return nil }
            var mask = 0
            for index in [latest, showing, pending?.index ?? -1] where index >= 0 {
                mask |= 1 << index
            }
            return mask
        }
    }

    // MARK: Compositor

    /// Whether every pixel of the newest frame is opaque.
    public var isOpaque: Bool {
        locked { opaque }
    }

    /// Whether a frame was published that the compositor hasn't taken, or
    /// one is still being drawn by the GPU.
    public var hasNewFrame: Bool {
        locked { unshown || pending != nil }
    }

    /// The size of the newest frame, in pixels.
    public var pixelSize: CGSize {
        locked {
            if !buffersFailed, let buffer = buffers.first {
                return CGSize(width: CGFloat(buffer.width), height: CGFloat(buffer.height))
            }
            return frame.map { CGSize(width: CGFloat($0.width), height: CGFloat($0.height)) } ?? .zero
        }
    }

    /// Whether frames come in shared buffers the compositor can still try
    /// to import.
    public var usesBuffers: Bool {
        locked { !buffers.isEmpty && !buffersFailed }
    }

    /// The newest frame of pixels, now the one shown; `nil` before any.
    public func takeFrame() -> Frame? {
        locked {
            unshown = false
            return frame
        }
    }

    /// The newest finished shared buffer, now the one on screen. Waits a
    /// few milliseconds for a frame that is nearly finished. `nil` before
    /// any frame is.
    public func takeBuffer() -> TakenBuffer? {
        // The fence is polled on a duplicate, as the producer may pass the
        // frame over, closing it, meanwhile.
        if let (index, fence) = locked({ pending.map { ($0.index, dup($0.fence)) } }), fence >= 0 {
            var file = pollfd(fd: fence, events: Int16(POLLIN), revents: 0)
            let finished = poll(&file, 1, 3) > 0
            close(fence)
            if finished {
                locked {
                    guard let current = pending, current.index == index else { return }
                    latest = index
                    close(current.fence)
                    pending = nil
                }
            }
        }
        return locked {
            guard !buffersFailed, latest >= 0 else { return nil }
            showing = latest
            let frames = published
            published = 0
            unshown = false
            return TakenBuffer(index: latest, frames: frames, isWaiting: pending != nil)
        }
    }

    /// The compositor's: the shared buffers can't be imported, so the
    /// producer must publish pixels.
    public func failBuffers() {
        locked { buffersFailed = true }
    }
}

extension ExternalSurface: Hashable {

    /// Surfaces are equal by identity.
    public static func == (lhs: ExternalSurface, rhs: ExternalSurface) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// An external surface's newest frame, stretched to an item's frame.
public struct ExternalContent: Equatable, Sendable {

    public var surface: ExternalSurface

    /// Whether the frame is drawn smoothed when it's scaled.
    public var isSmooth: Bool

    public init(surface: ExternalSurface, isSmooth: Bool = true) {
        self.surface = surface
        self.isSmooth = isSmooth
    }
}
