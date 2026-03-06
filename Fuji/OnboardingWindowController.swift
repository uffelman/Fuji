//
//  OnboardingWindowController.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/8/26.
//

import AppKit
import SwiftUI

/// Manages the lifecycle of the onboarding window.
///
/// The window is a fixed-size, floating panel presented whenever the app launches
/// without accessibility permissions (or, in debug builds, when the developer toggle
/// is enabled). The user may dismiss it via the close button or the navigation
/// controls inside ``OnboardingView``.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let permissions: any PermissionsManaging

    init(permissions: any PermissionsManaging) {
        self.permissions = permissions
    }

    // MARK: - Public interface

    /// Presents the onboarding window.
    ///
    /// - Parameter startOnPage: The page index to open to. Pass `0` for the full
    ///   welcome + permissions flow, or `1` to jump straight to the permissions
    ///   page (used when the app already knows permissions are missing at launch).
    func show(startOnPage: Int = 0) {
        if window == nil {
            window = makeWindow(startOnPage: startOnPage)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Window construction

    private func makeWindow(startOnPage: Int) -> NSWindow {
        let win = NSWindow()
        win.title = "Welcome to Fuji"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = false
        win.isMovableByWindowBackground = true
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.delegate = self

        let fixedWidth: CGFloat = 480
        win.minSize = NSSize(width: fixedWidth, height: 100)
        win.maxSize = NSSize(width: fixedWidth, height: 10_000)

        let onboardingView = OnboardingView(
            onDismiss: { [weak self] in
                self?.close()
            },
            onWillRequestPermission: { [weak self] in
                self?.yieldWindowLevel()
            },
            permissions: permissions,
            startOnPage: startOnPage,
            onHeightChanged: { [weak win] _ in
                guard let win,
                      let contentView = win.contentViewController?.view else { return }
                // Re-measure the full view (page + footer) now that content has
                // settled, then resize keeping the top-left corner anchored.
                // Width is preserved because we never mutate frame.size.width.
                let newContentHeight = contentView.fittingSize.height
                let titlebarHeight = win.frame.height - win.contentRect(forFrameRect: win.frame).height
                let newFrameHeight = newContentHeight + titlebarHeight
                var frame = win.frame
                frame.origin.y += frame.height - newFrameHeight
                frame.size.height = newFrameHeight
                win.setFrame(frame, display: true, animate: true)
            }
        )

        let hostingController = NSHostingController(rootView: onboardingView)
        win.contentViewController = hostingController

        // Set the width first so the hosting view knows its horizontal constraint
        // when we ask for fittingSize. The height will be corrected immediately
        // by the first onHeightChanged callback once the view renders.
        win.setContentSize(NSSize(width: fixedWidth, height: fixedWidth)) // square placeholder
        hostingController.view.layout()
        let fittingHeight = hostingController.view.fittingSize.height
        win.setContentSize(NSSize(width: fixedWidth, height: fittingHeight))
        win.center()

        return win
    }

    // MARK: - Dismissal

    private func close() {
        window?.close()
    }

    // MARK: - Window level management

    /// Temporarily drops the onboarding window to `.normal` level so that the
    /// macOS system permission dialog — which appears at the normal level — is
    /// not obscured by our floating window.  The floating level is restored the
    /// next time the app becomes active (i.e. the user has dismissed or
    /// interacted with the system dialog and returned here).
    private func yieldWindowLevel() {
        guard let window, window.level == .floating else { return }
        window.level = .normal

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restoreWindowLevel),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func restoreWindowLevel() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        window?.level = .floating
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    /// Cleans up the window reference when the user clicks the close (✕) button.
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
