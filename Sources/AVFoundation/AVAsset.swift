//
//  AVAsset.swift
//  AVFoundation
//
//  Created by Alsey Coleman Miller on 11/23/26.
//

import Foundation

/// Media at a URL: a file, or a stream FFmpeg can read (HTTP, HLS).
public class AVAsset: NSObject, @unchecked Sendable {

    /// Where the media is.
    package let location: URL

    public init(url: URL) {
        self.location = url
    }
}

/// Media at a URL, which it tells.
public class AVURLAsset: AVAsset, @unchecked Sendable {

    public var url: URL { location }

    /// Creates an asset for the media at `url`. No options are used.
    public init(url: URL, options: [String: Any]? = nil) {
        super.init(url: url)
    }
}
