//
//  KeyboardShortcutManager.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import Carbon
import Foundation
import UserNotifications

@MainActor
final class KeyboardShortcutManager {
    private var eventHandler: EventHandlerRef?
    private var registeredHotKeys: [UInt32: (ref: EventHotKeyRef, shortcut: KeyboardShortcut)] = [:]
    private var nextHotKeyID: UInt32 = 1

    private let displayManager: DisplayManager
    private let settingsManager: SettingsManager

    var onShortcutTriggered: ((ResolutionPreset) -> Void)?

    init(displayManager: DisplayManager, settingsManager: SettingsManager) {
        self.displayManager = displayManager
        self.settingsManager = settingsManager
        setupEventHandler()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
        }
    }

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
            print("Failed to install event handler: \(status)")
        } else {
            print("Successfully installed event handler")
        }
    }

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
        print("Hotkey pressed with ID: \(hotkeyIDValue)")
        Task { @MainActor in
            if let entry = registeredHotKeys[hotkeyIDValue] {
                print("Found registered hotkey: \(entry.shortcut.displayString)")
                if let preset = settingsManager.preset(for: entry.shortcut) {
                    print("Found preset: \(preset.name)")
                    applyPreset(preset)
                } else {
                    print("No preset found for shortcut")
                }
            } else {
                print("No registered hotkey found for ID \(hotkeyIDValue)")
            }
        }

        return noErr
    }

    private func applyPreset(_ preset: ResolutionPreset) {
        let configurations = preset.configurations.map { config in
            (displayID: CGDirectDisplayID(config.displayID), mode: config.mode)
        }

        let success = displayManager.setMultipleDisplayModes(configurations)
        if success {
            showNotification(title: "Resolution Changed", message: "Applied preset: \(preset.name)")
        }

        onShortcutTriggered?(preset)
    }

    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

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
            print(
                "Registered hotkey: \(shortcut.displayString) with ID \(currentID), keyCode: \(shortcut.keyCode), modifiers: \(carbonModifiers)"
            )
            return true
        }

        print(
            "Failed to register hot key: \(status), keyCode: \(shortcut.keyCode), modifiers: \(carbonModifiers)"
        )
        return false
    }

    func unregisterHotKey(for shortcut: KeyboardShortcut) {
        for (id, entry) in registeredHotKeys {
            if entry.shortcut == shortcut {
                UnregisterEventHotKey(entry.ref)
                registeredHotKeys.removeValue(forKey: id)
                break
            }
        }
    }

    func unregisterAllHotKeys() {
        for (_, entry) in registeredHotKeys {
            UnregisterEventHotKey(entry.ref)
        }
        registeredHotKeys.removeAll()
    }

    func refreshHotKeys() {
        unregisterAllHotKeys()

        // Check accessibility permissions
        let hasPermission = AXIsProcessTrusted()
        if !hasPermission {
            print("⚠️ WARNING: Accessibility permissions not granted. Global hotkeys will not work.")
            print("   Please grant accessibility access in System Settings > Privacy & Security > Accessibility")
        }

        print("Refreshing hotkeys, found \(settingsManager.presets.count) presets")
        for preset in settingsManager.presets {
            if let shortcut = preset.keyboardShortcut {
                print("Registering hotkey for preset '\(preset.name)': \(shortcut.displayString)")
                let success = registerHotKey(for: shortcut)
                if success {
                    print("  ✓ Successfully registered")
                } else {
                    print("  ✗ Failed to register")
                }
            } else {
                print("Preset '\(preset.name)' has no keyboard shortcut")
            }
        }
        print("Hotkey registration complete. Total registered: \(registeredHotKeys.count)")
    }
}

// Helper class for keyboard shortcut recording
@MainActor
final class ShortcutRecorder: NSObject {
    private var monitor: Any?
    var onShortcutRecorded: ((KeyboardShortcut?) -> Void)?

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

    func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
