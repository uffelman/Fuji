//
//  MenuBarController.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import SwiftUI

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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "display", accessibilityDescription: "Display Resolution")
            button.image?.isTemplate = true
        }

        rebuildMenu()
    }

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

        // Sort resolutions by size
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
        if let currentMode = display.currentMode,
            currentMode.width == mode.width && currentMode.height == mode.height
                && currentMode.refreshRate == mode.refreshRate
                && currentMode.isHiDPI == mode.isHiDPI
        {
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

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? ResolutionPreset else { return }

        let configurations = preset.configurations.map { config in
            (displayID: CGDirectDisplayID(config.displayID), mode: config.mode)
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

    @objc private func refreshDisplays() {
        displayManager.refreshDisplays()
        rebuildMenu()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // Use the legacy window approach since SwiftUI Settings scene
        // cannot be opened reliably from outside SwiftUI
        openSettingsWindowLegacy()
    }

    // Keep the old implementation as fallback (unused now)
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

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
