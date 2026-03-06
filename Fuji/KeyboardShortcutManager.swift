//
//  KeyboardShortcutManager.swift
//  Fuji
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import Carbon
import Foundation
import OSLog

/// Manages global keyboard shortcuts for triggering resolution presets.
///
/// This class registers system-wide hotkeys using Carbon Event Manager APIs,
/// allowing shortcuts to work even when the app is in the background. It handles
/// shortcut registration, event processing, and preset application.
@MainActor
final class KeyboardShortcutManager {
    private var eventHandler: EventHandlerRef?
    private var registeredHotKeys: [UInt32: (ref: EventHotKeyRef, shortcut: KeyboardShortcut)] = [:]
    private var nextHotKeyID: UInt32 = 1

    private let displayManager: any DisplayManaging
    private let settingsManager: SettingsManager
    private let permissionsManager: any PermissionsManaging
    private let resolutionOverlayController: ResolutionOverlayController

    var onShortcutTriggered: ((ResolutionPreset) -> Void)?

    /// Called when an increment/decrement hotkey is triggered.
    /// The Bool parameter is `true` for increase, `false` for decrease.
    var onIncrementTriggered: ((Bool) -> Void)?

    private var incrementUpHotKeyID: UInt32?
    private var incrementDownHotKeyID: UInt32?

    var registeredHotKeyCount: Int {
        return registeredHotKeys.count
    }

    init(
        displayManager: any DisplayManaging,
        settingsManager: SettingsManager,
        permissionsManager: any PermissionsManaging,
        resolutionOverlayController: ResolutionOverlayController
    ) {
        self.displayManager = displayManager
        self.settingsManager = settingsManager
        self.permissionsManager = permissionsManager
        self.resolutionOverlayController = resolutionOverlayController
        setupEventHandler()
    }

    deinit {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        for (_, entry) in registeredHotKeys {
            UnregisterEventHotKey(entry.ref)
        }
    }

    /// Sets up the Carbon event handler for receiving hotkey events.
    ///
    /// Registers a global event handler that receives keyboard hotkey pressed events
    /// from the system. Uses GetEventDispatcherTarget() to ensure the handler receives
    /// events even when the app is in the background.
    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Use GetEventDispatcherTarget() for global hotkeys that work even when app is in background
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(userData)
                    .takeUnretainedValue()
                return manager.handleHotKeyEvent(event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            Logger.app.error("Failed to install event handler: \(status)")
        } else {
            Logger.app.info("Successfully installed event handler")
        }
    }

    /// Handles incoming hotkey pressed events.
    ///
    /// Extracts the hotkey ID from the event, looks up the corresponding shortcut and preset,
    /// and applies the preset to the displays. This method is called from a non-isolated context
    /// and dispatches preset application to the main actor.
    ///
    /// - Parameter event: The Carbon event containing hotkey information
    /// - Returns: OSStatus indicating whether the event was handled
    nonisolated private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return status }

        // Find the shortcut for this hot key ID
        let hotkeyIDValue = hotKeyID.id
        Logger.app.info("Hotkey pressed with ID: \(hotkeyIDValue)")
        Task { @MainActor in
            // Check if this is an increment/decrement hotkey
            if hotkeyIDValue == self.incrementUpHotKeyID {
                Logger.app.info("Increment up hotkey pressed")
                self.onIncrementTriggered?(true)
                return
            }
            if hotkeyIDValue == self.incrementDownHotKeyID {
                Logger.app.info("Increment down hotkey pressed")
                self.onIncrementTriggered?(false)
                return
            }

            // Otherwise check preset hotkeys
            if let entry = registeredHotKeys[hotkeyIDValue] {
                Logger.app.info("Found registered hotkey: \(entry.shortcut.displayString)")
                if let preset = settingsManager.preset(for: entry.shortcut) {
                    Logger.app.info("Found preset: \(preset.name)")
                    applyPreset(preset)
                } else {
                    Logger.app.error("No preset found for shortcut")
                }
            } else {
                Logger.app.error("No registered hotkey found for ID \(hotkeyIDValue)")
            }
        }

        return noErr
    }

    /// Applies a resolution preset to all configured displays.
    ///
    /// Refreshes the display list, matches preset configurations to current displays,
    /// applies the resolution changes, and shows a notification with the result.
    ///
    /// - Parameter preset: The preset to apply
    private func applyPreset(_ preset: ResolutionPreset) {
        // Refresh displays to ensure we have current IDs
        displayManager.refreshDisplays()
        
        // Use smart display matching from extension
        guard let configurations = preset.matchConfigurations(to: displayManager) else {
            return
        }

        let success = displayManager.setMultipleDisplayModes(configurations)
        if success {
            let overlayLines = configurations.compactMap { config -> OverlayLine? in
                guard let display = displayManager.displays.first(where: { $0.id == config.displayID }) else {
                    return nil
                }
                return OverlayLine(
                    displayID: config.displayID,
                    displayName: display.name,
                    resolution: config.mode.displayString
                )
            }
            resolutionOverlayController.show(
                presetName: preset.name,
                configurations: overlayLines
            )
        }

        onShortcutTriggered?(preset)
    }

    /// Registers a global hotkey with the system.
    ///
    /// Converts the shortcut's modifier flags to Carbon format and registers it using
    /// the Carbon Event Manager. Assigned hotkey IDs are tracked for later lookup when events arrive.
    ///
    /// - Parameter shortcut: The keyboard shortcut to register
    /// - Returns: `true` if registration succeeded, `false` otherwise
    func registerHotKey(for shortcut: KeyboardShortcut) -> Bool {
        // Convert from Carbon event modifiers to RegisterEventHotKey format
        // The modifiers stored in KeyboardShortcut use the old Carbon event format,
        // but RegisterEventHotKey expects them in a different format
        var carbonModifiers: UInt32 = 0

        // Convert Carbon event modifiers to Carbon hotkey modifiers
        if shortcut.modifiers & UInt32(cmdKey) != 0 {
            carbonModifiers |= UInt32(cmdKey)
        }
        if shortcut.modifiers & UInt32(shiftKey) != 0 {
            carbonModifiers |= UInt32(shiftKey)
        }
        if shortcut.modifiers & UInt32(optionKey) != 0 {
            carbonModifiers |= UInt32(optionKey)
        }
        if shortcut.modifiers & UInt32(controlKey) != 0 {
            carbonModifiers |= UInt32(controlKey)
        }

        let currentID = nextHotKeyID
        let hotKeyID = EventHotKeyID(signature: OSType(0x4453_504C), id: currentID)  // 'DSPL'
        nextHotKeyID += 1

        var hotKeyRef: EventHotKeyRef?
        // Use GetApplicationEventTarget() - hotkeys registered here will be delivered
        // to our event handler installed with GetEventDispatcherTarget()
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            registeredHotKeys[currentID] = (ref: ref, shortcut: shortcut)
            Logger.app.info(
                "Registered hotkey: \(shortcut.displayString) with ID \(currentID), keyCode: \(shortcut.keyCode), modifiers: \(carbonModifiers)"
            )
            return true
        }

        Logger.app.error(
            "Failed to register hot key: \(status), keyCode: \(shortcut.keyCode), modifiers: \(carbonModifiers)"
        )
        return false
    }

    /// Unregisters a previously registered hotkey.
    ///
    /// Searches for the hotkey matching the given shortcut and removes it from the system.
    /// - Parameter shortcut: The keyboard shortcut to unregister
    func unregisterHotKey(for shortcut: KeyboardShortcut) {
        for (id, entry) in registeredHotKeys {
            if entry.shortcut == shortcut {
                UnregisterEventHotKey(entry.ref)
                registeredHotKeys.removeValue(forKey: id)
                break
            }
        }
    }

    /// Unregisters all currently registered hotkeys.
    func unregisterAllHotKeys() {
        for (_, entry) in registeredHotKeys {
            UnregisterEventHotKey(entry.ref)
        }
        registeredHotKeys.removeAll()
    }

    /// Refreshes all hotkey registrations from the current preset list.
    ///
    /// Unregisters all existing hotkeys and re-registers them based on the current presets
    /// in SettingsManager. Checks for accessibility permissions and logs detailed information
    /// about registration success. Implements automatic retry logic if not all shortcuts register successfully.
    ///
    /// - Parameter retryCount: Number of retries already attempted (max 2)
    func refreshHotKeys(retryCount: Int = 0) {
        unregisterAllHotKeys()

        // Reset increment tracking
        incrementUpHotKeyID = nil
        incrementDownHotKeyID = nil

        // Check accessibility permissions
        let hasPermission = permissionsManager.isAccessibilityTrusted
        if !hasPermission {
            Logger.app.error("Accessibility permissions not granted. Global hotkeys will not work.")
            // Don't return - attempt to register anyway as permissions might be pending
        }

        // Register increment shortcuts if enabled
        if settingsManager.enableIncrementShortcuts {
            let upShortcut = settingsManager.effectiveIncrementUpShortcut
            let upID = nextHotKeyID
            if registerHotKey(for: upShortcut) {
                incrementUpHotKeyID = upID
                Logger.app.info("Registered increment up hotkey: \(upShortcut.displayString)")
            }

            let downShortcut = settingsManager.effectiveIncrementDownShortcut
            let downID = nextHotKeyID
            if registerHotKey(for: downShortcut) {
                incrementDownHotKeyID = downID
                Logger.app.info("Registered increment down hotkey: \(downShortcut.displayString)")
            }
        }

        Logger.app.info("Refreshing hotkeys, found \(self.settingsManager.presets.count) presets")
        var successCount = 0
        for preset in settingsManager.presets {
            if let shortcut = preset.keyboardShortcut {
                Logger.app.info("Registering hotkey for preset '\(preset.name)': \(shortcut.displayString)")
                let success = registerHotKey(for: shortcut)
                if success {
                    Logger.app.info("Successfully registered hotkey for '\(preset.name)'")
                    successCount += 1
                } else {
                    Logger.app.error("Failed to register hotkey for '\(preset.name)'")
                }
            }
        }
        Logger.app.info("Hotkey registration complete. Total registered: \(self.registeredHotKeys.count)/\(successCount) attempted")

        // If we failed to register some hotkeys, schedule a retry (max 2 attempts)
        let expectedPresetCount = settingsManager.presets.filter { $0.keyboardShortcut != nil }.count
        let expectedIncrementCount = settingsManager.enableIncrementShortcuts ? 2 : 0
        let expectedCount = expectedPresetCount + expectedIncrementCount
        if registeredHotKeys.count < expectedCount && retryCount < 2 {
            Logger.app.error("Not all hotkeys registered (\(self.registeredHotKeys.count)/\(expectedCount)). Retry \(retryCount + 1) in 2 seconds...")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                if self.registeredHotKeys.count < expectedCount {
                    self.refreshHotKeys(retryCount: retryCount + 1)
                }
            }
        }
    }
}

/// Helper class for recording keyboard shortcuts from user input.
///
/// Monitors keyboard events and converts them into KeyboardShortcut objects.
/// Used in the preset editor to allow users to define custom shortcuts.
@MainActor
final class ShortcutRecorder: NSObject {
    private var monitor: Any?
    var onShortcutRecorded: ((KeyboardShortcut?) -> Void)?

    /// Begins monitoring for keyboard events to record a shortcut.
    ///
    /// Installs a local event monitor that captures key down events and converts them
    /// to KeyboardShortcut objects. Automatically stops recording when a valid shortcut is captured.
    func startRecording() {
        stopRecording()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let shortcut = KeyboardShortcut.from(event: event) {
                self?.onShortcutRecorded?(shortcut)
                self?.stopRecording()
                return nil
            }
            return event
        }
    }

    /// Stops monitoring keyboard events and removes the event monitor.
    func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
