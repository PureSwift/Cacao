//
//  CoreGraphics.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/30/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// Prevents ambigous reference in Darwin

import Silica

public typealias CGContext = Silica.Context
public typealias CGColor = Silica.Color
public typealias CGFloat = Double
public typealias CGLineCap = Silica.LineCap
public typealias CGLineJoin = Silica.LineJoin
public typealias CGPathDrawingMode = Silica.DrawingMode
public typealias CGTextDrawingMode = Silica.TextDrawingMode
public typealias CGAffineTransform = Silica.AffineTransform
public typealias CGPath = Silica.Path
public typealias CGPathElement = Silica.CGPathElement
public typealias CGPathApplierFunction = (UnsafeMutablePointer<Void>, UnsafePointer<CGPathElement>) -> ()
public typealias CGSize = Silica.Size
public typealias CGPoint = Silica.Point
public typealias CGRect = Silica.Rect
public typealias CGFont = Silica.Font