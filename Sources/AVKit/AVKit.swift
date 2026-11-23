//
//  AVKit.swift
//  AVKit
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

// On Linux, `import AVKit` resolves to this module, so sources written
// against Apple's compile unchanged: its `VideoPlayer` view, for Cacao.
// Like Apple's, it brings AVFoundation in too. This target exists only on
// Linux; see the manifest.

@_exported import AVFoundation
