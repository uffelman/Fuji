//
//  MenuBarController.swift
//  Fuji
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import SwiftUI

/// Manages the menu bar status item and its menu.
///
/// Creates and maintains the app's menu bar presence, building dynamic menus that show
/// available displays, resolution options, presets, and app controls. Handles user interactions
/// and coordinates with DisplayManager for resolution changes.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    
    private let displayManager: any DisplayManaging
    private let resolutionOverlayController: ResolutionOverlayController
    private let settingsManager: SettingsManager
    
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var settingsWindow: NSWindow?
    private var increaseResolutionItem: NSMenuItem?
    private var decreaseResolutionItem: NSMenuItem?
    
    var makeSettingsViewController: (() -> NSViewController?)?

    init(
        displayManager: any DisplayManaging,
        resolutionOverlayController: ResolutionOverlayController,
        settingsManager: SettingsManager
    ) {
        self.displayManager = displayManager
        self.settingsManager = settingsManager
        self.resolutionOverlayController = resolutionOverlayController
        super.init()
    }

    /// Creates the status bar item and initializes the menu.
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "display", accessibilityDescription: "Display Resolution")
            button.image?.isTemplate = true
        }

        rebuildMenu()
    }

    /// Rebuilds the entire menu with current display and preset information.
    ///
    /// This method is called whenever displays change, presets are modified, or resolutions
    /// are applied. It dynamically generates menu items for all displays, their modes, and
    /// available presets.
    func rebuildMenu() {
        menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        // Add displays and their resolutions
        for display in displayManager.displays {
            addDisplaySection(display)
        }

        // Add presets section if there are any
        let presets = settingsManager.presets
        if !presets.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let presetsHeader = NSMenuItem(title: "Presets", action: nil, keyEquivalent: "")
            presetsHeader.isEnabled = false
            presetsHeader.attributedTitle = NSAttributedString(
                string: "Presets",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]
            )
            menu.addItem(presetsHeader)

            for preset in presets {
                let presetItem = NSMenuItem(
                    title: preset.name,
                    action: #selector(applyPreset(_:)),
                    keyEquivalent: ""
                )
                presetItem.target = self
                presetItem.representedObject = preset

                if let shortcut = preset.keyboardShortcut {
                    presetItem.toolTip = "Shortcut: \(shortcut.displayString)"
                }

                // Show ratio badges for each configuration's resolution
                let ratioLabels = preset.configurations.compactMap {
                    $0.mode.aspectRatioLabel
                }
                applyInlineRatioBadge(
                    to: presetItem, title: preset.name,
                    font: NSFont.menuFont(ofSize: 0), ratioLabels: ratioLabels)

                menu.addItem(presetItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Increment/Decrement resolution items
        let increaseItem = NSMenuItem(
            title: "Increase Resolution",
            action: #selector(increaseResolution),
            keyEquivalent: ""
        )
        increaseItem.target = self
        if settingsManager.enableIncrementShortcuts {
            increaseItem.toolTip = "Shortcut: \(settingsManager.effectiveIncrementUpShortcut.displayString)"
        }
        self.increaseResolutionItem = increaseItem
        menu.addItem(increaseItem)

        let decreaseItem = NSMenuItem(
            title: "Decrease Resolution",
            action: #selector(decreaseResolution),
            keyEquivalent: ""
        )
        decreaseItem.target = self
        if settingsManager.enableIncrementShortcuts {
            decreaseItem.toolTip = "Shortcut: \(settingsManager.effectiveIncrementDownShortcut.displayString)"
        }
        self.decreaseResolutionItem = decreaseItem
        menu.addItem(decreaseItem)

        menu.addItem(NSMenuItem.separator())

        // Refresh option
        let refreshItem = NSMenuItem(
            title: "Refresh Displays", action: #selector(refreshDisplays), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        // Reset to default
        let resetItem = NSMenuItem(
            title: "Reset to Default", action: #selector(resetToDefault), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Fuji", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// Adds a section to the menu for a specific display.
    ///
    /// Creates a display header, current resolution indicator, and submenu with all available
    /// resolution modes grouped by resolution dimensions.
    ///
    /// - Parameter display: The display to add to the menu
    private func addDisplaySection(_ display: Display) {
        // Display header
        let headerItem = NSMenuItem(title: display.displayLabel, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        headerItem.attributedTitle = NSAttributedString(
            string: display.displayLabel,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]
        )
        menu.addItem(headerItem)

        // Current resolution info
        if let currentMode = display.currentMode {
            let currentItem = NSMenuItem(
                title: "  Current: \(currentMode.displayString)",
                action: nil,
                keyEquivalent: ""
            )
            currentItem.isEnabled = false
            currentItem.attributedTitle = NSAttributedString(
                string: "  Current: \(currentMode.displayString)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
            menu.addItem(currentItem)
        }

        // Submenu for all resolutions
        let resolutionsItem = NSMenuItem(
            title: "  Change Resolution", action: nil, keyEquivalent: "")
        let resolutionsSubmenu = NSMenu()

        // Group modes by resolution
        var modesByResolution: [String: [DisplayMode]] = [:]
        for mode in display.modes {
            let key = "\(mode.width)×\(mode.height)"
            modesByResolution[key, default: []].append(mode)
        }

        // Sort resolutions by pixel dimensions (larger to smaller)
        // Parses the resolution strings (e.g., "1920×1080") to compare numerically
        let sortedResolutions = modesByResolution.keys.sorted { key1, key2 in
            let parts1 = key1.split(separator: "×").compactMap { Int($0) }
            let parts2 = key2.split(separator: "×").compactMap { Int($0) }
            if parts1.count == 2 && parts2.count == 2 {
                if parts1[0] != parts2[0] {
                    return parts1[0] > parts2[0]
                }
                return parts1[1] > parts2[1]
            }
            return key1 > key2
        }

        for resolution in sortedResolutions {
            guard let modes = modesByResolution[resolution] else { continue }

            if modes.count == 1 {
                // Single mode for this resolution
                let mode = modes[0]
                let modeItem = createModeMenuItem(mode: mode, display: display)
                resolutionsSubmenu.addItem(modeItem)
            } else {
                // Multiple modes (different refresh rates or HiDPI variants)
                // Check if any mode in this group is the default
                let containsDefault = modes.contains { display.isDefaultMode($0) }
                let resTitle = containsDefault ? "\(resolution) - Default" : resolution

                let resItem = NSMenuItem(title: resTitle, action: nil, keyEquivalent: "")
                let resSubmenu = NSMenu()

                for mode in modes.sorted(by: { $0.refreshRate > $1.refreshRate }) {
                    let modeItem = createModeMenuItem(
                        mode: mode, display: display, showFullDetails: true)
                    resSubmenu.addItem(modeItem)
                }

                // Style the resolution group header with optional ratio badge
                let ratioLabels = [modes.first?.aspectRatioLabel].compactMap { $0 }
                let font: NSFont = containsDefault
                    ? .systemFont(ofSize: 13, weight: .medium)
                    : .menuFont(ofSize: 0)
                applyInlineRatioBadge(
                    to: resItem, title: resTitle, font: font, ratioLabels: ratioLabels)

                resItem.submenu = resSubmenu
                resolutionsSubmenu.addItem(resItem)
            }
        }

        resolutionsItem.submenu = resolutionsSubmenu
        menu.addItem(resolutionsItem)

        menu.addItem(NSMenuItem.separator())
    }

    /// Creates a menu item for a specific display mode.
    ///
    /// Builds a menu item with appropriate title formatting, checkmark for current mode,
    /// and special styling for the default mode.
    ///
    /// - Parameters:
    ///   - mode: The display mode
    ///   - display: The display that owns this mode
    ///   - showFullDetails: Whether to show full mode details (refresh rate, HiDPI) or just resolution
    /// - Returns: A configured NSMenuItem
    private func createModeMenuItem(
        mode: DisplayMode, display: Display, showFullDetails: Bool = false
    ) -> NSMenuItem {
        var title = showFullDetails ? mode.displayString : mode.shortDisplayString

        // Add "Default" label if this is the default mode for the display
        let isDefault = display.isDefaultMode(mode)
        if isDefault {
            title += " - Default"
        }

        let item = NSMenuItem(
            title: title, action: #selector(selectResolution(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = (display.id, mode)

        // Check if this is the current mode
        // Use DisplayMode's == operator which properly compares all properties
        if let currentMode = display.currentMode, currentMode == mode {
            item.state = .on
        }

        // Build title with optional inline ratio badge (preserves native checkmark/chevron)
        let font: NSFont = isDefault
            ? .systemFont(ofSize: 13, weight: .medium)
            : .menuFont(ofSize: 0)
        let ratioLabels = [mode.aspectRatioLabel].compactMap { $0 }
        applyInlineRatioBadge(
            to: item, title: title, font: font, ratioLabels: ratioLabels)

        return item
    }

    /// Handles selection of a resolution from the menu.
    ///
    /// Extracts the display ID and mode from the menu item's represented object and
    /// applies the resolution change.
    ///
    /// - Parameter sender: The menu item that was clicked
    @objc private func selectResolution(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? (CGDirectDisplayID, DisplayMode) else {
            return
        }
        let (displayID, mode) = info

        Task {
            let success = displayManager.setDisplayMode(mode, for: displayID)
            if success {
                displayManager.refreshDisplays()
                rebuildMenu()
                if let display = displayManager.displays.first(where: { $0.id == displayID }) {
                    resolutionOverlayController.show(
                        displayName: display.name,
                        resolution: mode.displayString
                    )
                }
            } else {
                showAlert(
                    title: "Failed to Change Resolution",
                    message:
                        "Could not change the display resolution. The selected mode may not be supported."
                )
            }
        }
    }

    /// Applies a resolution preset from the menu.
    ///
    /// Matches the preset's configurations to current displays and applies all
    /// resolution changes atomically.
    ///
    /// - Parameter sender: The menu item representing the preset
    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? ResolutionPreset else { return }

        // Refresh displays to ensure we have current IDs
        displayManager.refreshDisplays()
        
        // Use smart display matching from extension
        guard let configurations = preset.matchConfigurations(to: displayManager) else {
            showAlert(
                title: "Display Not Found",
                message: "Could not apply preset '\(preset.name)' - display configuration changed"
            )
            return
        }

        Task {
            let success = displayManager.setMultipleDisplayModes(configurations)
            if success {
                displayManager.refreshDisplays()
                rebuildMenu()
                let overlayLines = configurations.compactMap { config -> OverlayLine? in
                    guard let display = displayManager.displays.first(where: { $0.id == config.displayID }) else {
                        return nil
                    }
                    return OverlayLine(displayName: display.name, resolution: config.mode.displayString)
                }
                resolutionOverlayController.show(
                    presetName: preset.name,
                    configurations: overlayLines
                )
            } else {
                showAlert(
                    title: "Failed to Apply Preset",
                    message:
                        "Could not apply the preset '\(preset.name)'. Some display modes may not be available."
                )
            }
        }
    }

    /// Refreshes the display list and rebuilds the menu.
    @objc private func refreshDisplays() {
        displayManager.refreshDisplays()
        rebuildMenu()
    }

    /// Resets all displays to their default resolutions.
    @objc private func resetToDefault() {
        let success = displayManager.resetAllToDefault()
        if success {
            displayManager.refreshDisplays()
            rebuildMenu()
            let overlayLines = displayManager.displays.compactMap { display -> OverlayLine? in
                guard let defaultMode = display.defaultMode else { return nil }
                return OverlayLine(displayName: display.name, resolution: defaultMode.displayString)
            }
            resolutionOverlayController.show(
                presetName: "Reset to Default",
                configurations: overlayLines
            )
        } else {
            showAlert(
                title: "Failed to Reset Displays",
                message: "Could not reset displays to their default resolutions."
            )
        }
    }

    /// Opens the settings window.
    @objc private func openSettings() {
        // Use the legacy window approach since SwiftUI Settings scene
        // cannot be opened reliably from outside SwiftUI.
        openSettingsWindowLegacy()
    }
    
    private func makeSettingsWindow() -> NSWindow {
        guard let factory = makeSettingsViewController, let hostingController = factory() else {
            fatalError("AppDelegate did not properly configure MenuBarController")
        }

        let contentSize = NSSize(
            width: SettingsViewMetrics.size.width,
            height: SettingsViewMetrics.size.height
        )

        let settingsWindow = NSWindow(contentViewController: hostingController)
        settingsWindow.title = "Fuji Settings"
        settingsWindow.styleMask = [.titled, .closable, .miniaturizable]
        settingsWindow.setContentSize(contentSize)
        settingsWindow.minSize = contentSize
        settingsWindow.maxSize = contentSize
        settingsWindow.center()
        settingsWindow.isReleasedWhenClosed = false
        
        return settingsWindow
    }

    /// Creates and displays a standalone settings window using NSHostingController.
    ///
    /// This legacy approach creates a window manually when the SwiftUI Settings scene
    /// is not reliably accessible from outside SwiftUI contexts.
    private func openSettingsWindowLegacy() {
        if settingsWindow == nil {
            settingsWindow = makeSettingsWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Terminates the application.
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Applies aspect ratio badge(s) to a menu item as an inline attributed title.
    ///
    /// Uses NSTextAttachment to append badge images after the title text.
    /// This preserves native NSMenuItem behavior (checkmarks, submenu chevrons).
    ///
    /// - Parameters:
    ///   - item: The menu item to configure
    ///   - title: The title text
    ///   - font: The font to use for the title
    ///   - ratioLabels: The ratio label strings (e.g. ["16:9"]), empty to skip badges
    private func applyInlineRatioBadge(
        to item: NSMenuItem, title: String, font: NSFont,
        ratioLabels: [String]
    ) {
        let result = NSMutableAttributedString(
            string: title, attributes: [.font: font])
        for label in ratioLabels {
            let badgeImage = createRatioBadgeImage(text: label)
            let attachment = NSTextAttachment()
            attachment.image = badgeImage
            let yOffset = (font.pointSize - badgeImage.size.height) / 2 - 1
            attachment.bounds = NSRect(
                x: 0, y: yOffset,
                width: badgeImage.size.width, height: badgeImage.size.height)
            result.append(NSAttributedString(string: "  "))
            result.append(NSAttributedString(attachment: attachment))
        }
        item.attributedTitle = result
    }

    /// Creates an NSImage of a small round-rect badge containing the given text.
    private func createRatioBadgeImage(text: String, fontSize: CGFloat = 9) -> NSImage {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let hPadding: CGFloat = 5
        let vPadding: CGFloat = 1.5
        let badgeSize = NSSize(
            width: textSize.width + hPadding * 2,
            height: textSize.height + vPadding * 2)

        let image = NSImage(size: badgeSize, flipped: false) { rect in
            let path = NSBezierPath(
                roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            NSColor.secondaryLabelColor.withAlphaComponent(0.15).setFill()
            path.fill()
            let textRect = NSRect(
                x: hPadding, y: vPadding,
                width: textSize.width, height: textSize.height)
            (text as NSString).draw(in: textRect, withAttributes: attributes)
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateIncrementMenuItemState()
    }

    /// Updates the enabled state of increment/decrement menu items based on the display under the mouse.
    private func updateIncrementMenuItemState() {
        guard let display = displayManager.displayUnderMouse() else {
            increaseResolutionItem?.isEnabled = false
            decreaseResolutionItem?.isEnabled = false
            return
        }

        increaseResolutionItem?.isEnabled = display.nextHigherResolution() != nil
        decreaseResolutionItem?.isEnabled = display.nextLowerResolution() != nil
    }

    // MARK: - Resolution Increment

    @objc private func increaseResolution() {
        incrementResolution(increase: true)
    }

    @objc private func decreaseResolution() {
        incrementResolution(increase: false)
    }

    /// Steps the display under the mouse cursor to the next resolution group.
    ///
    /// Finds the display under the mouse, determines the next higher or lower resolution group,
    /// applies the mode change, shows the overlay, and rebuilds the menu. Beeps on failure.
    ///
    /// - Parameter increase: If true, steps to a higher resolution; if false, steps lower
    func incrementResolution(increase: Bool) {
        displayManager.refreshDisplays()

        guard let display = displayManager.displayUnderMouse() else {
            NSSound.beep()
            return
        }

        let targetMode: DisplayMode? = increase
            ? display.nextHigherResolution()
            : display.nextLowerResolution()

        guard let mode = targetMode else {
            NSSound.beep()
            return
        }

        let success = displayManager.setDisplayMode(mode, for: display.id)
        if success {
            displayManager.refreshDisplays()
            rebuildMenu()
            resolutionOverlayController.show(
                displayName: display.name,
                resolution: mode.displayString
            )
        } else {
            NSSound.beep()
        }
    }

    /// Displays an alert dialog with the given title and message.
    ///
    /// - Parameters:
    ///   - title: The alert title
    ///   - message: The alert message text
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
