//
//  AVFoundation.swift
//  AVFoundation
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

// On Linux, `import AVFoundation` resolves to this module, so sources
// written against Apple's compile unchanged: a subset of it, for playing
// media, on PureSwift/Media. Like Apple's, it brings Foundation and
// CoreMedia in too. This target exists only on Linux; see the manifest.

@_exported import Foundation
@_exported import CoreMedia
