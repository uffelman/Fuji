//
//  ResolutionOverlayController.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/27/26.
//

import AppKit
import CoreGraphics
import SwiftUI

/// Manages floating HUD overlays that briefly display the new resolution after a display mode switch.
///
/// Each overlay appears in the top-right corner of the display whose resolution changed, styled
/// similarly to the macOS volume/brightness HUD. Overlays fade in, stay visible for approximately
/// 2 seconds, then fade out. If a new resolution change occurs while overlays are visible, the
/// content updates and the dismiss timer resets.
@MainActor
final class ResolutionOverlayController {

    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private var dismissTask: Task<Void, Never>?
    
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    /// Shows the overlay on a single display after a resolution change.
    ///
    /// - Parameters:
    ///   - displayName: The name of the display that changed
    ///   - resolution: The new resolution string (e.g. "1920 × 1080 @ 60Hz (HiDPI)")
    ///   - displayID: The Core Graphics display ID to position the overlay on
    func show(displayName: String, resolution: String, on displayID: CGDirectDisplayID) {
        guard settingsManager.showResolutionOverlay else { return }
        let line = OverlayLine(displayID: displayID, displayName: displayName, resolution: resolution)
        let overlayView = ResolutionOverlayView(lines: [line])
        presentOverlays([(displayID, overlayView)])
    }

    /// Shows an overlay on each affected display for a multi-display preset application.
    ///
    /// - Parameters:
    ///   - presetName: The name of the preset that was applied
    ///   - configurations: Each display's overlay line including its displayID
    func show(presetName: String, configurations: [OverlayLine]) {
        guard settingsManager.showResolutionOverlay else { return }
        let entries = configurations.map { line in
            let overlayView = ResolutionOverlayView(
                lines: [line],
                presetName: presetName
            )
            return (line.displayID, overlayView)
        }
        presentOverlays(entries)
    }

    /// Immediately dismisses all overlays if visible.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        animateOut()
    }

    // MARK: - Private

    private func presentOverlays(_ entries: [(CGDirectDisplayID, ResolutionOverlayView)]) {
        dismissTask?.cancel()
        dismissTask = nil

        // Remove windows for displays that are no longer targeted so animateIn
        // only operates on windows that should be visible.
        let targetIDs = Set(entries.map(\.0))
        for displayID in windows.keys where !targetIDs.contains(displayID) {
            windows[displayID]?.orderOut(nil)
            windows[displayID] = nil
        }

        for (displayID, overlayView) in entries {
            let window = windows[displayID] ?? makeWindow()
            windows[displayID] = window

            let hostingController = NSHostingController(rootView: overlayView)
            window.contentViewController = hostingController

            let fittingSize = hostingController.view.fittingSize
            window.setContentSize(fittingSize)

            if let screen = screen(for: displayID) {
                positionWindow(window, on: screen)
            }
        }

        animateIn()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.animateOut()
        }
    }

    /// Resolves a Core Graphics display ID to its corresponding NSScreen.
    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID
            return screenNumber == displayID
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

    private func positionWindow(_ window: NSWindow, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let padding: CGFloat = 16

        let x = visibleFrame.maxX - windowSize.width - padding
        let y = visibleFrame.maxY - windowSize.height - padding
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func animateIn() {
        for window in windows.values {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in self.windows.values {
                window.animator().alphaValue = 1
            }
        }
    }

    private func animateOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in self.windows.values {
                window.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                for window in self.windows.values {
                    window.orderOut(nil)
                }
            }
        })
    }
}
