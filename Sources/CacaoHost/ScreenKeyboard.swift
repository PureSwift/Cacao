//
//  ScreenKeyboard.swift
//  CacaoHost
//
//  Created by Alsey Coleman Miller on 11/20/26.
//

#if os(iOS)
import Foundation
import UIKit

/// Follows the on-screen keyboard on iOS, where SDL says when it shows and
/// hides but not where it is.
@MainActor
internal final class ScreenKeyboard {

    static let shared = ScreenKeyboard()

    /// Where the keyboard is on screen, or where it's going while it
    /// animates there; `nil` while it's hidden.
    private(set) var frame: CGRect?

    private init() {
        let center = NotificationCenter.default
        center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { notification in
            let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            MainActor.assumeIsolated { ScreenKeyboard.shared.set(frame) }
        }
        center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { ScreenKeyboard.shared.set(nil) }
        }
    }

    private func set(_ frame: CGRect?) {
        guard self.frame != frame else { return }
        self.frame = frame
        // A frame, to lay out again in the room that's left.
        HostRuntime.wake()
    }
}
#endif
