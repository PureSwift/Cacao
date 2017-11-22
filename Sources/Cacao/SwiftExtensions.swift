//
//  SwiftExtensions.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/22/17.
//
//


#if swift(>=4.0)

#elseif swift(>=3.0.2)

internal extension MutableCollection {
    
    /// Exchanges the values at the specified indices of the collection.
    ///
    /// Both parameters must be valid indices of the collection that are not
    /// equal to `endIndex`. Calling `swapAt(_:_:)` with the same index as both
    /// `i` and `j` has no effect.
    ///
    /// - Parameters:
    ///   - i: The index of the first value to swap.
    ///   - j: The index of the second value to swap.
    @_inlineable
    mutating func swapAt(_ i: Index, _ j: Index) {
        guard i != j else { return }
        let tmp = self[i]
        self[i] = self[j]
        self[j] = tmp
    }
}
    
internal extension Dictionary {
    
    subscript(
        key: Key, default defaultValue: @autoclosure () -> Value
        ) -> Value {

        @inline(__always)
        get {
            return self[key] ?? defaultValue()
        }
        set {
            
            self[key] = newValue
        }
    }
}

#endif
