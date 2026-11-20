//
//  SharedBuffers.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/19/26.
//

import Foundation
import CacaoRender
import SDL3Swift

/// Imports an external surface's shared GPU buffers (dma-bufs) as SDL
/// textures, so their frames are drawn without passing through the CPU.
///
/// Each buffer becomes an EGL image bound to the GL texture of a new SDL
/// texture, in SDL's context. This needs SDL's OpenGL ES 2 renderer
/// (`HostRuntime.rendererName = "opengles2"`) and the host's EGL to import
/// dma-bufs; anywhere else nothing is imported, and the surface's producer
/// publishes pixels instead.
@MainActor
enum SharedBuffers {

    struct Imported {
        var texture: SDLTexture
        /// The EGL image, destroyed with the texture.
        var image: UnsafeMutableRawPointer?
    }

    #if os(Linux)

    typealias Pointer = UnsafeMutableRawPointer

    private static var loaded: Bool?
    private static var getCurrentDisplay: (@convention(c) () -> Pointer?)!
    private static var createImage: (@convention(c) (Pointer?, Pointer?, UInt32, Pointer?, UnsafePointer<Int32>?) -> Pointer?)!
    private static var destroyImage: (@convention(c) (Pointer?, Pointer?) -> UInt32)!
    private static var getIntegerv: (@convention(c) (UInt32, UnsafeMutablePointer<Int32>?) -> Void)!
    private static var bindTexture: (@convention(c) (UInt32, UInt32) -> Void)!
    private static var imageTargetTexture: (@convention(c) (UInt32, Pointer?) -> Void)!
    private static var getError: (@convention(c) () -> UInt32)!

    /// Binds EGL and OpenGL ES from the host's libraries, once; false where
    /// the host lacks any of the functions.
    private static func load() -> Bool {
        if let loaded { return loaded }
        var complete = true
        func bind<T>(_ library: Pointer?, _ name: String, _ fallback: ((UnsafePointer<CChar>) -> Pointer?)? = nil) -> T? {
            guard let symbol = library.flatMap({ dlsym($0, name) }) ?? fallback?(name) else {
                complete = false
                return nil
            }
            return unsafeBitCast(symbol, to: T.self)
        }
        let egl = dlopen("libEGL.so.1", RTLD_NOW), gles = dlopen("libGLESv2.so.2", RTLD_NOW)
        let procAddress: (@convention(c) (UnsafePointer<CChar>) -> Pointer?)? = bind(egl, "eglGetProcAddress")
        let extensionFunction: (UnsafePointer<CChar>) -> Pointer? = { procAddress?($0) }
        getCurrentDisplay = bind(egl, "eglGetCurrentDisplay")
        createImage = bind(egl, "eglCreateImageKHR", extensionFunction)
        destroyImage = bind(egl, "eglDestroyImageKHR", extensionFunction)
        getIntegerv = bind(gles, "glGetIntegerv")
        bindTexture = bind(gles, "glBindTexture")
        imageTargetTexture = bind(gles, "glEGLImageTargetTexture2DOES", extensionFunction)
        getError = bind(gles, "glGetError")
        loaded = complete
        return complete
    }

    /// The buffer imported: an EGL image of the dma-buf, bound to the GL
    /// texture of a new SDL texture, in SDL's context, whose bindings are
    /// left as they were. `nil` if the host or the renderer can't.
    static func importBuffer(_ buffer: ExternalSurface.Buffer, renderer: SDLRenderer) -> Imported? {
        guard buffer.fileDescriptor >= 0, load() else { return nil }
        let display = getCurrentDisplay()
        // EGL_WIDTH, EGL_HEIGHT, EGL_LINUX_DRM_FOURCC_EXT, plane 0's fd,
        // offset and pitch, and its modifier when it has one.
        var attributes: [Int32] = [
            0x3057, buffer.width, 0x3056, buffer.height, 0x3271, Int32(bitPattern: buffer.fourCC),
            0x3272, buffer.fileDescriptor, 0x3273, buffer.offset, 0x3274, buffer.stride,
        ]
        if buffer.modifier != ExternalSurface.Buffer.noModifier {
            attributes += [
                0x3443, Int32(truncatingIfNeeded: buffer.modifier),
                0x3444, Int32(truncatingIfNeeded: buffer.modifier >> 32),
            ]
        }
        attributes.append(0x3038) // EGL_NONE
        // EGL_LINUX_DMA_BUF_EXT, with no context and no client buffer.
        guard let image = createImage(display, nil, 0x3270, nil, attributes) else { return nil }
        // Static access: SDL never writes to it.
        guard let texture = try? SDLTexture(
            renderer: renderer, format: .abgr8888, access: .static, width: Int(buffer.width), height: Int(buffer.height)
        ) else {
            _ = destroyImage(display, image)
            return nil
        }
        // The texture's GL name, which only the OpenGL ES 2 renderer has.
        let name = texture.properties.number("SDL.texture.opengles2.texture")
        guard name != 0 else {
            _ = destroyImage(display, image)
            return nil
        }
        var previous: Int32 = 0
        getIntegerv(0x8069, &previous) // GL_TEXTURE_BINDING_2D
        while getError() != 0 { }
        bindTexture(0x0DE1, UInt32(name)) // GL_TEXTURE_2D
        imageTargetTexture(0x0DE1, image)
        let error = getError()
        bindTexture(0x0DE1, UInt32(previous))
        guard error == 0 else {
            _ = destroyImage(display, image)
            return nil
        }
        return Imported(texture: texture, image: image)
    }

    /// Destroys the EGL image of an imported buffer.
    static func destroyImage(_ image: UnsafeMutableRawPointer) {
        guard loaded == true else { return }
        _ = destroyImage(getCurrentDisplay(), image)
    }

    #else

    static func importBuffer(_ buffer: ExternalSurface.Buffer, renderer: SDLRenderer) -> Imported? {
        nil
    }

    static func destroyImage(_ image: UnsafeMutableRawPointer) { }

    #endif
}
