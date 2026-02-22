//
//  ResolutionOverlayController.swift
//  DisplayApp
//

import AppKit
import SwiftUI

/// Manages a floating HUD overlay that briefly displays the new resolution after a display mode switch.
///
/// The overlay appears in the top-right corner of the main screen, styled similarly to the macOS
/// volume/brightness HUD. It fades in, stays visible for approximately 2 seconds, then fades out.
/// If a new resolution change occurs while the overlay is visible, the content updates and the
/// dismiss timer resets.
@MainActor
final class ResolutionOverlayController {

    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?
    
    private let settingsManager: any SettingsManaging

    init(settingsManager: any SettingsManaging) {
        self.settingsManager = settingsManager
    }

    /// Shows the overlay for a single display resolution change.
    ///
    /// - Parameters:
    ///   - displayName: The name of the display that changed
    ///   - resolution: The new resolution string (e.g. "1920 × 1080 @ 60Hz (HiDPI)")
    func show(displayName: String, resolution: String) {
        guard settingsManager.showResolutionOverlay else { return }
        let overlayView = ResolutionOverlayView(
            lines: [OverlayLine(displayName: displayName, resolution: resolution)]
        )
        presentOverlay(overlayView)
    }

    /// Shows the overlay for a multi-display preset application.
    ///
    /// - Parameters:
    ///   - presetName: The name of the preset that was applied
    ///   - configurations: Each display's name and new resolution
    func show(presetName: String, configurations: [OverlayLine]) {
        guard settingsManager.showResolutionOverlay else { return }
        let overlayView = ResolutionOverlayView(
            lines: configurations,
            presetName: presetName
        )
        presentOverlay(overlayView)
    }

    /// Immediately dismisses the overlay if visible.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        animateOut()
    }

    // MARK: - Private

    private func presentOverlay(_ overlayView: ResolutionOverlayView) {
        dismissTask?.cancel()
        dismissTask = nil

        if window == nil {
            window = makeWindow()
        }

        let hostingController = NSHostingController(rootView: overlayView)
        window?.contentViewController = hostingController

        // Compute content size and apply it to the window before positioning
        let fittingSize = hostingController.view.fittingSize
        window?.setContentSize(fittingSize)

        positionWindow()
        animateIn()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.animateOut()
        }
    }

    private func makeWindow() -> NSWindow {
        let win = NSWindow()
        win.styleMask = [.borderless]
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.ignoresMouseEvents = true
        win.isReleasedWhenClosed = false
        return win
    }

    private func positionWindow() {
        guard let window, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let padding: CGFloat = 16

        let x = visibleFrame.maxX - windowSize.width - padding
        let y = visibleFrame.maxY - windowSize.height - padding
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func animateIn() {
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        }
    }

    private func animateOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.window?.orderOut(nil)
            }
        })
    }
}
