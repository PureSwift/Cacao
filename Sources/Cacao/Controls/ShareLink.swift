//
//  ShareLink.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/14/26.
//

import CacaoRender
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// What to share, asked of the host.
package struct ShareRequest {

    /// The items: strings, URLs, data or other transferable values.
    package let items: [Any]

    package let subject: String?

    package let message: String?

    /// The frame of the link that shares, in the window.
    package let anchor: CGRect
}

/// A view that controls a sharing presentation.
///
/// Where the host shows the system's share picker (on macOS), the link
/// opens it; elsewhere, it shows a menu that copies the items and opens
/// URLs.
public struct ShareLink<Data: RandomAccessCollection, PreviewImage, PreviewIcon, Label: View>: View where Data.Element: Transferable {

    internal let items: Data

    internal let subject: Text?

    internal let message: Text?

    internal let label: Label

    public var body: some View {
        _ShareLinkContent(
            items: items.map { $0 as Any },
            subject: subject?.runs.map(\.string).joined(),
            message: message?.runs.map(\.string).joined(),
            label: AnyView(label)
        )
    }
}

/// A preview of content to share.
public struct SharePreview<Image, Icon> {

    internal let title: Text

    internal let image: Image?

    internal let icon: Icon?

    /// Creates a preview with a title.
    public init<S: StringProtocol>(_ title: S) where Image == Never, Icon == Never {
        self.title = Text(title)
        self.image = nil
        self.icon = nil
    }

    /// Creates a preview with a title and an image.
    public init<S: StringProtocol>(_ title: S, image: Image) where Icon == Never {
        self.title = Text(title)
        self.image = image
        self.icon = nil
    }

    /// Creates a preview with a title and an icon.
    public init<S: StringProtocol>(_ title: S, icon: Icon) where Image == Never {
        self.title = Text(title)
        self.image = nil
        self.icon = icon
    }

    /// Creates a preview with a title, an image and an icon.
    public init<S: StringProtocol>(_ title: S, image: Image, icon: Icon) {
        self.title = Text(title)
        self.image = image
        self.icon = icon
    }
}

/// The default label of a share link: a share icon and "Share".
public struct DefaultShareLinkLabel: View {

    internal let title: Text

    public var body: some View {
        Label(title: { title }, icon: { Image(systemName: "square.and.arrow.up") })
    }
}

// MARK: - Initializers

extension ShareLink where PreviewImage == Never, PreviewIcon == Never, Label == DefaultShareLinkLabel {

    /// Creates a share link for a collection of items.
    public init(items: Data, subject: Text? = nil, message: Text? = nil) {
        self.init(storing: items, subject: subject, message: message, label: DefaultShareLinkLabel(title: Text("Share")))
    }

    /// Creates a share link for an item.
    public init<I: Transferable>(item: I, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<I> {
        self.init(storing: CollectionOfOne(item), subject: subject, message: message, label: DefaultShareLinkLabel(title: Text("Share")))
    }

    /// Creates a share link for an item, with a title.
    public init<I: Transferable>(_ titleKey: LocalizedStringKey, item: I, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<I> {
        self.init(storing: CollectionOfOne(item), subject: subject, message: message, label: DefaultShareLinkLabel(title: Text(titleKey)))
    }

    /// Creates a share link for an item, with a title.
    @_disfavoredOverload
    public init<S: StringProtocol, I: Transferable>(_ title: S, item: I, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<I> {
        self.init(storing: CollectionOfOne(item), subject: subject, message: message, label: DefaultShareLinkLabel(title: Text(title)))
    }

    /// Creates a share link for a collection of items, with a title.
    public init(_ titleKey: LocalizedStringKey, items: Data, subject: Text? = nil, message: Text? = nil) {
        self.init(storing: items, subject: subject, message: message, label: DefaultShareLinkLabel(title: Text(titleKey)))
    }
}

extension ShareLink where PreviewImage == Never, PreviewIcon == Never {

    /// Creates a share link for a collection of items, with a custom label.
    public init(items: Data, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) {
        self.init(storing: items, subject: subject, message: message, label: label())
    }

    /// Creates a share link for an item, with a custom label.
    public init<I: Transferable>(item: I, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) where Data == CollectionOfOne<I> {
        self.init(storing: CollectionOfOne(item), subject: subject, message: message, label: label())
    }
}

extension ShareLink where Label == DefaultShareLinkLabel {

    /// Creates a share link for an item, with a preview.
    public init<I: Transferable>(
        item: I,
        subject: Text? = nil,
        message: Text? = nil,
        preview: SharePreview<PreviewImage, PreviewIcon>
    ) where Data == CollectionOfOne<I> {
        self.init(storing: CollectionOfOne(item), subject: subject, message: message, label: DefaultShareLinkLabel(title: Text("Share")))
    }

    /// Creates a share link for an item, with a title and a preview.
    public init<I: Transferable>(
        _ titleKey: LocalizedStringKey,
        item: I,
        subject: Text? = nil,
        message: Text? = nil,
        preview: SharePreview<PreviewImage, PreviewIcon>
    ) where Data == CollectionOfOne<I> {
        self.init(storing: CollectionOfOne(item), subject: subject, message: message, label: DefaultShareLinkLabel(title: Text(titleKey)))
    }
}

extension ShareLink {

    /// Creates a share link for an item, with a preview and a custom label.
    public init<I: Transferable>(
        item: I,
        subject: Text? = nil,
        message: Text? = nil,
        preview: SharePreview<PreviewImage, PreviewIcon>,
        @ViewBuilder label: () -> Label
    ) where Data == CollectionOfOne<I> {
        self.init(storing: CollectionOfOne(item), subject: subject, message: message, label: label())
    }

    internal init(storing items: Data, subject: Text?, message: Text?, label: Label) {
        self.items = items
        self.subject = subject
        self.message = message
        self.label = label
    }
}

// MARK: - Content

/// A share link's control: a button that asks the host to share, or a menu
/// of what Cacao can do itself.
private struct _ShareLinkContent: View, PrimitiveView {

    let items: [Any]

    let subject: String?

    let message: String?

    let label: AnyView

    func resolve(in context: ResolveContext) -> Resolution {
        weak let graph = context.graph
        context.graph.shareLinks = context.graph.shareLinks.filter { $0.value.node != nil }
        context.graph.shareLinks[context.node.id] = WeakNodeReference(context.node)
        guard graph?.share == nil else {
            weak let node = context.node
            let request = { ShareRequest(items: items, subject: subject, message: message, anchor: node?.windowFrame ?? .zero) }
            let button = Button(action: { _ = graph?.share?(request()) }) { label }
            return Resolution(children: [ChildView(key: "share", view: button)])
        }
        let text = items.map(Self.text(of:)).joined(separator: "\n")
        let urls = items.compactMap { $0 as? URL }
        let openURL = context.environment.openURL
        let menu = Menu {
            Button("Copy") { graph?.clipboard?.write(text) }
            ForEach(urls.indices, id: \.self) { index in
                Button(urls.count == 1 ? "Open" : "Open \(urls[index].lastPathComponent)") {
                    openURL(urls[index])
                }
            }
        } label: {
            label
        }
        return Resolution(children: [ChildView(key: "menu", view: menu)])
    }

    /// An item as text to copy.
    static func text(of item: Any) -> String {
        switch item {
        case let string as String:
            string
        case let url as URL:
            url.isFileURL ? url.path : url.absoluteString
        case let data as Foundation.Data:
            String(data: data, encoding: .utf8) ?? ""
        default:
            String(describing: item)
        }
    }

    typealias Body = Never
}
