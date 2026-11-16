//
//  Combine.swift
//  Combine
//
//  Created by Alsey Coleman Miller on 11/15/26.
//

// On Linux, `import Combine` resolves to the part of Combine that Cacao
// provides (`ObservableObject`, `Published`, publishers and subscriptions),
// so sources written against Apple's frameworks compile unchanged. This
// target exists only on Linux; see the manifest.

@_exported import Foundation
@_exported import Cacao
