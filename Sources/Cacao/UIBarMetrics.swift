//
//  UIBarMetrics.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/15/17.
//

/// Constants to specify metrics to use for appearance.
public enum UIBarMetrics {
    
    /// Specifies default metrics for the device.
    case `default`
    
    /// Specifies metrics when using the phone idiom.
    case compact
    
    /// Specifies default metrics for the device for bars with the prompt property,
    /// such as `UINavigationBar` and `UISearchBar`.
    case defaultPrompt
    
    /// Specifies metrics for bars with the prompt property when using the phone idiom,
    /// such as `UINavigationBar` and `UISearchBar`.
    case compactPrompt
}
