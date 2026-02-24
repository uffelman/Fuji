//
//  KeyboardShortcut.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/15/26.
//

import AppKit
import Carbon
import Foundation

/// Represents a keyboard shortcut with key code and modifier keys.
///
/// Stores the raw key code and modifier flags from Carbon events, providing
/// conversion to human-readable strings for display in the UI.
struct KeyboardShortcut: Codable, Hashable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    /// A human-readable representation of the keyboard shortcut.
    ///
    /// Uses Unicode symbols for modifier keys (⌃ ⌥ ⇧ ⌘) followed by the key character.
    /// Example: "⌘⇧P"
    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    /// Maps a key code to its string representation.
    ///
    /// Includes alphabetic keys, numbers, function keys, and special keys.
    /// - Parameter keyCode: The raw key code from a keyboard event
    /// - Returns: The string representation of the key, or nil if unmapped
    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        let keyCodeMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
            51: "Delete", 53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "F2",
            120: "F1", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyCodeMap[keyCode]
    }

    /// Creates a KeyboardShortcut from an NSEvent.
    ///
    /// Extracts the key code and modifier flags from a key down event.
    /// Requires at least one modifier key to be valid.
    ///
    /// - Parameter event: The keyboard event to convert
    /// - Returns: A KeyboardShortcut, or nil if no modifiers are present
    static func from(event: NSEvent) -> KeyboardShortcut? {
        var modifiers: UInt32 = 0

        if event.modifierFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if event.modifierFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if event.modifierFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        // Require at least one modifier
        guard modifiers != 0 else { return nil }

        return KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }
}

