//
//  ForEach.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

/// A structure that computes views on demand from an underlying collection
/// of identified data.
///
/// Each element's view is identified by the element's `id`, so state
/// follows the element when the collection is reordered.
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content> {

    /// The collection of underlying identified data.
    public var data: Data

    /// A function to create content on demand using the underlying data.
    public var content: (Data.Element) -> Content

    internal let identifier: (Data.Element) -> ID
}

extension ForEach: View where Content: View {

    public typealias Body = Never

    /// Creates an instance that uniquely identifies and creates views across
    /// updates based on the provided key path to the underlying data's identifier.
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
        self.identifier = { $0[keyPath: id] }
    }
}

extension ForEach where ID == Data.Element.ID, Content: View, Data.Element: Identifiable {

    /// Creates an instance that uniquely identifies and creates views across
    /// updates based on the identity of the underlying data.
    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data, id: \.id, content: content)
    }
}

extension ForEach where Data == Range<Int>, ID == Int, Content: View {

    /// Creates an instance that computes views on demand over a given
    /// constant range.
    public init(
        _ data: Range<Int>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.data = data
        self.content = content
        self.identifier = { $0 }
    }
}

extension ForEach: PrimitiveView where Content: View {

    func resolve(in context: ResolveContext) -> Resolution {
        Resolution(children: data.map { element in
            ChildView(key: identifier(element), view: content(element))
        })
    }
}
