//
//  App.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - App

/// A type that represents the structure and behavior of an app.
///
/// `main()` comes from the host module, `CacaoSDL` (re-exported by
/// `SwiftUI` on Linux), so mark the app with `@main` in a file that imports it.
@MainActor
@preconcurrency
public protocol App {

    /// The type of scene representing the content of the app.
    associatedtype Body: Scene

    /// The content and behavior of the app.
    @SceneBuilder
    var body: Self.Body { get }

    /// Creates an instance of the app using the body that you define for its content.
    init()
}

// MARK: - Scene

/// A part of an app's user interface with a life cycle managed by the system.
@MainActor
@preconcurrency
public protocol Scene {

    /// The type of scene that represents the body of this scene.
    associatedtype Body: Scene

    /// The content and behavior of the scene.
    @SceneBuilder
    var body: Self.Body { get }
}

extension Never: Scene { }

/// A scene Cacao describes directly instead of through its body.
@MainActor
internal protocol PrimitiveScene {

    func windows(modifiers: SceneModifiers) -> [WindowDescription]
}

/// Settings applied to scenes by scene modifiers.
internal struct SceneModifiers {

    var defaultSize: CGSize?
}

/// A window a host should open for an app.
package struct WindowDescription {

    /// The window's title.
    package var title: String

    /// The scene identifier, if any.
    package var id: String?

    /// The window's initial content size, in points.
    package var defaultSize: CGSize?

    /// The window's root view.
    package var rootView: AnyView
}

extension Scene {

    /// The windows a host opens for this scene, in order.
    package func windowDescriptions() -> [WindowDescription] {
        sceneWindows(of: self, modifiers: SceneModifiers())
    }
}

@MainActor
internal func sceneWindows<S: Scene>(of scene: S, modifiers: SceneModifiers) -> [WindowDescription] {
    if let primitive = scene as? any PrimitiveScene {
        return primitive.windows(modifiers: modifiers)
    }
    return sceneWindows(of: scene.body, modifiers: modifiers)
}

// MARK: - SceneBuilder

/// A result builder for composing a collection of scenes into a single
/// composite scene.
@MainActor
@preconcurrency
@resultBuilder
public struct SceneBuilder {

    public static func buildExpression<Content: Scene>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<Content: Scene>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<each Content: Scene>(_ content: repeat each Content) -> _TupleScene<(repeat each Content)> {
        var scenes: [any Scene] = []
        for scene in repeat each content {
            scenes.append(scene)
        }
        return _TupleScene((repeat each content), scenes: scenes)
    }

    public static func buildOptional<Content: Scene>(_ content: Content?) -> Content? {
        content
    }
}

extension Optional: Scene where Wrapped: Scene {

    public typealias Body = Never

    public var body: Never {
        fatalError("Optional is a primitive scene")
    }
}

extension Optional: PrimitiveScene where Wrapped: Scene {

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        switch self {
        case let .some(scene): sceneWindows(of: scene, modifiers: modifiers)
        case .none: []
        }
    }
}

/// A scene made of several scenes.
public struct _TupleScene<T>: Scene, PrimitiveScene {

    public var value: T

    internal let scenes: [any Scene]

    internal init(_ value: T, scenes: [any Scene]) {
        self.value = value
        self.scenes = scenes
    }

    public typealias Body = Never

    public var body: Never {
        fatalError("_TupleScene is a primitive scene")
    }

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        scenes.flatMap { sceneWindows(of: $0, modifiers: modifiers) }
    }
}

// MARK: - WindowGroup

/// A scene that presents a group of identically structured windows.
public struct WindowGroup<Content: View>: Scene, PrimitiveScene {

    internal let title: String?

    internal let id: String?

    internal let content: Content

    /// Creates a window group.
    public init(@ViewBuilder content: () -> Content) {
        self.title = nil
        self.id = nil
        self.content = content()
    }

    /// Creates a window group with a title.
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.id = nil
        self.content = content()
    }

    /// Creates a window group with an identifier.
    public init(id: String, @ViewBuilder content: () -> Content) {
        self.title = nil
        self.id = id
        self.content = content()
    }

    /// Creates a window group with a title and an identifier.
    public init(_ title: String, id: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.id = id
        self.content = content()
    }

    public typealias Body = Never

    public var body: Never {
        fatalError("WindowGroup is a primitive scene")
    }

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        [WindowDescription(
            title: title ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ProcessInfo.processInfo.processName,
            id: id,
            defaultSize: modifiers.defaultSize,
            rootView: AnyView(content)
        )]
    }
}

/// A scene that presents its content in a single, unique window.
public struct Window<Content: View>: Scene, PrimitiveScene {

    internal let title: String

    internal let id: String

    internal let content: Content

    /// Creates a window with a title and an identifier.
    public init(_ title: String, id: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.id = id
        self.content = content()
    }

    public typealias Body = Never

    public var body: Never {
        fatalError("Window is a primitive scene")
    }

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        [WindowDescription(title: title, id: id, defaultSize: modifiers.defaultSize, rootView: AnyView(content))]
    }
}

// MARK: - Scene modifiers

/// A scene with a modifier applied.
public struct _SceneModifierContent<Content: Scene>: Scene, PrimitiveScene {

    internal let content: Content

    internal let modify: (inout SceneModifiers) -> Void

    public typealias Body = Never

    public var body: Never {
        fatalError("_SceneModifierContent is a primitive scene")
    }

    func windows(modifiers: SceneModifiers) -> [WindowDescription] {
        var modifiers = modifiers
        modify(&modifiers)
        return sceneWindows(of: content, modifiers: modifiers)
    }
}

extension Scene {

    /// Sets a default size for a window.
    public func defaultSize(width: CGFloat, height: CGFloat) -> some Scene {
        _SceneModifierContent(content: self) { $0.defaultSize = CGSize(width: width, height: height) }
    }

    /// Sets a default size for a window.
    public func defaultSize(_ size: CGSize) -> some Scene {
        defaultSize(width: size.width, height: size.height)
    }
}
