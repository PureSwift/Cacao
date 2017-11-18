//
//  UIViewAutoresizing.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 11/18/17.
//

import Foundation

/// Options for automatic view resizing.
public struct UIViewAutoresizing : OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Options for automatic view resizing.
    public static let flexibleLeftMargin = UIViewAutoresizing(rawValue: 1 << 0)
    public static let flexibleWidth = UIViewAutoresizing(rawValue: 1 << 1)
    public static let flexibleRightMargin = UIViewAutoresizing(rawValue: 1 << 2)
    public static let flexibleTopMargin = UIViewAutoresizing(rawValue: 1 << 3)
    public static let flexibleHeight = UIViewAutoresizing(rawValue: 1 << 4)
    public static let flexibleBottomMargin = UIViewAutoresizing(rawValue: 1 << 5)
}

// MARK: - Internal Extension

internal extension CGRect {
    
    mutating func resize(_ autoresizingMask: UIViewAutoresizing, containerSize: (old: CGSize, new: CGSize)) {
        
        self = resized(autoresizingMask, containerSize: containerSize)
    }
    
    func resized(_ autoresizingMask: UIViewAutoresizing, containerSize: (old: CGSize, new: CGSize)) -> CGRect {
        
        guard autoresizingMask.isEmpty == false else { return self }
        
        let oldSize = containerSize.old
        
        let newSize = containerSize.new
        
        var frame = self
        
        let delta = CGSize(width: newSize.width - oldSize.width, height: newSize.height - oldSize.height)
        
        if autoresizingMask.contains([.flexibleTopMargin, .flexibleHeight, .flexibleBottomMargin]) {
            frame.origin.y = floor(frame.origin.y + (frame.origin.y / oldSize.height * delta.height))
            frame.size.height = floor(frame.size.height + (frame.size.height / oldSize.height * delta.height))
        }
        else if autoresizingMask.contains([.flexibleTopMargin, .flexibleHeight]) {
            let t = frame.origin.y + frame.size.height
            frame.origin.y = floor(frame.origin.y + (frame.origin.y / t * delta.height))
            frame.size.height = floor(frame.size.height + (frame.size.height / t * delta.height))
        }
        else if autoresizingMask.contains([.flexibleBottomMargin, .flexibleHeight]) {
            frame.size.height = floor(frame.size.height + (frame.size.height / (oldSize.height - frame.origin.y) * delta.height))
        }
        else if autoresizingMask.contains([.flexibleBottomMargin, .flexibleTopMargin]) {
            frame.origin.y = floor(frame.origin.y + (delta.height / 2.0))
        }
        else if autoresizingMask.contains(.flexibleHeight) {
            frame.size.height = floor(frame.size.height + delta.height)
        }
        else if autoresizingMask.contains(.flexibleTopMargin) {
            frame.origin.y = floor(frame.origin.y + delta.height)
        }
        else if autoresizingMask.contains(.flexibleBottomMargin) {
            frame.origin.y = floor(frame.origin.y)
        }
        if autoresizingMask.contains([.flexibleLeftMargin, .flexibleWidth, .flexibleRightMargin]) {
            frame.origin.x = floor(frame.origin.x + (frame.origin.x / oldSize.width * delta.width))
            frame.size.width = floor(frame.size.width + (frame.size.width / oldSize.width * delta.width))
        }
        else if autoresizingMask.contains([.flexibleLeftMargin, .flexibleWidth]) {
            let t = frame.origin.x + frame.size.width
            frame.origin.x = floor(frame.origin.x + (frame.origin.x / t * delta.width))
            frame.size.width = floor(frame.size.width + (frame.size.width / t * delta.width))
        }
        else if autoresizingMask.contains([.flexibleRightMargin, .flexibleWidth]) {
            frame.size.width = floor(frame.size.width + (frame.size.width / (oldSize.width - frame.origin.x) * delta.width))
        }
        else if autoresizingMask.contains([.flexibleRightMargin, .flexibleLeftMargin]) {
            frame.origin.x = floor(frame.origin.x + (delta.width / 2.0))
        }
        else if autoresizingMask.contains(.flexibleWidth) {
            frame.size.width = floor(frame.size.width + delta.width)
        }
        else if autoresizingMask.contains(.flexibleLeftMargin) {
            frame.origin.x = floor(frame.origin.x + delta.width)
        }
        else if autoresizingMask.contains(.flexibleRightMargin) {
            frame.origin.x = floor(frame.origin.x)
        }
        
        return frame
    }
}
