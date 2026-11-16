//
//  DynamicProperty.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/13/26.
//

/// An interface for a stored variable that updates an external property of
/// a view.
///
/// Cacao finds dynamic properties (such as `@State` and `@Environment`) in a
/// view's stored properties, including inside nested dynamic properties, and
/// connects them to the view's node before it evaluates `body`.
public protocol DynamicProperty {

    /// Updates the underlying value of the stored value.
    mutating func update()
}

extension DynamicProperty {

    public mutating func update() { }
}

/// A dynamic property that connects itself to the node evaluating its view.
@MainActor
internal protocol DynamicPropertyInstaller {

    func install(in node: ViewNode, label: String)
}

@MainActor
internal enum DynamicProperties {

    /// Connects every dynamic property stored in `value` to `node`.
    static func install(in value: Any, node: ViewNode, prefix: String = "") {
        for (index, child) in Mirror(reflecting: value).children.enumerated() {
            let label = prefix + (child.label ?? "\(index)")
            if let installer = child.value as? any DynamicPropertyInstaller {
                installer.install(in: node, label: label)
            } else if child.value is any DynamicProperty {
                // A custom dynamic property: connect the ones it contains.
                install(in: child.value, node: node, prefix: label + ".")
            }
        }
    }
}
