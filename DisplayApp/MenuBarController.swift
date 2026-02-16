//
//  MenuBarController.swift
//  DisplayApp
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
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let displayManager: DisplayManager
    private let settingsManager: SettingsManager
    private var settingsWindow: NSWindow?

    init(displayManager: DisplayManager, settingsManager: SettingsManager) {
        self.displayManager = displayManager
        self.settingsManager = settingsManager
        super.init()
        setupStatusItem()
    }

    /// Creates the status bar item and initializes the menu.
    private func setupStatusItem() {
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

                menu.addItem(presetItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Refresh option
        let refreshItem = NSMenuItem(
            title: "Refresh Displays", action: #selector(refreshDisplays), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit DisplayApp", action: #selector(quitApp), keyEquivalent: "q")
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

                // Style the default resolution item
                if containsDefault {
                    resItem.attributedTitle = NSAttributedString(
                        string: resTitle,
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
                        ]
                    )
                }

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

        // Style the default mode item differently
        if isDefault {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium)
                ]
            )
        }

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
                rebuildMenu()
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
                rebuildMenu()
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

    /// Opens the settings window.
    @objc private func openSettings() {
        // Use the legacy window approach since SwiftUI Settings scene
        // cannot be opened reliably from outside SwiftUI
        openSettingsWindowLegacy()
    }

    /// Creates and displays a standalone settings window using NSHostingController.
    ///
    /// This legacy approach creates a window manually when the SwiftUI Settings scene
    /// is not reliably accessible from outside SwiftUI contexts.
    private func openSettingsWindowLegacy() {
        if settingsWindow == nil {
            let settingsView = SettingsView(
                displayManager: displayManager,
                settingsManager: settingsManager,
                onPresetsChanged: { [weak self] in
                    self?.rebuildMenu()
                }
            )

            let hostingController = NSHostingController(rootView: settingsView)

            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "DisplayApp Settings"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow?.setContentSize(NSSize(width: 600, height: 500))
            settingsWindow?.minSize = NSSize(width: 500, height: 400)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Terminates the application.
    @objc private func quitApp() {
        NSApp.terminate(nil)
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
