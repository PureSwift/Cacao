//
//  UIViewAnimation.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/24/17.
//

public final class UIViewAnimation {
    
    
}

// MARK: - Supporting Types

public enum UIViewAnimationCurve: Int {
    
    case easeInOut
    case easeIn
    case easeOut
    case linear
}

public enum UIViewAnimationTransition: Int {
    
    case none
    case flipFromLeft
    case flipFromRight
    case curlUp
    case curlDown
}

///
public struct UIViewAnimationOptions: OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        
        self.rawValue = rawValue
    }
    
    public static let layoutSubviews = UIViewAnimationOptions(rawValue: 1 << 0)
    public static let allowUserInteraction = UIViewAnimationOptions(rawValue: 1 << 1)
    public static let beginFromCurrentState = UIViewAnimationOptions(rawValue: 1 << 2)
    public static let `repeat` = UIViewAnimationOptions(rawValue: 1 << 3)
    public static let autoreverse = UIViewAnimationOptions(rawValue: 1 << 4)
    public static let overrideInheritedDuration = UIViewAnimationOptions(rawValue: 1 << 5)
    public static let overrideInheritedCurve = UIViewAnimationOptions(rawValue: 1 << 6)
    public static let allowAnimatedContent = UIViewAnimationOptions(rawValue: 1 << 7)
    public static let showHideTransitionViews = UIViewAnimationOptions(rawValue: 1 << 8)
    public static let curveEaseInOut = UIViewAnimationOptions(rawValue: 0 << 16)
    public static let curveEaseIn = UIViewAnimationOptions(rawValue: 1 << 16)
    public static let curveEaseOut = UIViewAnimationOptions(rawValue: 2 << 16)
    public static let curveLinear = UIViewAnimationOptions(rawValue: 3 << 16)
    public static let transitionNone = UIViewAnimationOptions(rawValue: 0 << 20)
    public static let transitionFlipFromLeft = UIViewAnimationOptions(rawValue: 1 << 20)
    public static let transitionFlipFromRight = UIViewAnimationOptions(rawValue: 2 << 20)
    public static let transitionCurlUp = UIViewAnimationOptions(rawValue: 3 << 20)
    public static let transitionCurlDown = UIViewAnimationOptions(rawValue: 4 << 20)
    public static let transitionCrossDissolve = UIViewAnimationOptions(rawValue: 5 << 20)
    public static let transitionFlipFromTop = UIViewAnimationOptions(rawValue: 6 << 20)
    public static let transitionFlipFromBottom = UIViewAnimationOptions(rawValue: 7 << 20)
}
