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

    /// Default shortcut for incrementing resolution: ⌃⌥↑
    static let defaultIncrementUp = KeyboardShortcut(
        keyCode: 126, modifiers: UInt32(controlKey) | UInt32(optionKey))

    /// Default shortcut for decrementing resolution: ⌃⌥↓
    static let defaultIncrementDown = KeyboardShortcut(
        keyCode: 125, modifiers: UInt32(controlKey) | UInt32(optionKey))

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

        if let keyString = Self.keyCodeMap[keyCode] {
            parts.append(keyString)
        }

        return parts.joined()
    }

    /// The key equivalent string for use with `NSMenuItem.keyEquivalent`.
    var menuKeyEquivalent: String {
        switch keyCode {
        case 123: return "\u{F702}" // Left arrow
        case 124: return "\u{F703}" // Right arrow
        case 125: return "\u{F701}" // Down arrow
        case 126: return "\u{F700}" // Up arrow
        case 122: return "\u{F704}" // F1
        case 120: return "\u{F705}" // F2
        case 99:  return "\u{F706}" // F3
        case 118: return "\u{F707}" // F4
        case 96:  return "\u{F708}" // F5
        case 97:  return "\u{F709}" // F6
        case 98:  return "\u{F70A}" // F7
        case 100: return "\u{F70B}" // F8
        case 101: return "\u{F70C}" // F9
        case 109: return "\u{F70D}" // F10
        case 103: return "\u{F70E}" // F11
        case 111: return "\u{F70F}" // F12
        case 105: return "\u{F710}" // F13
        case 107: return "\u{F711}" // F14
        case 113: return "\u{F712}" // F15
        case 48:  return "\t"       // Tab
        case 49:  return " "        // Space
        case 51:  return "\u{7F}"   // Delete (backspace)
        case 119: return "\u{F728}" // Forward delete
        case 53:  return "\u{1B}"   // Escape
        default:
            if let str = Self.keyCodeMap[keyCode] {
                return str.lowercased()
            }
            return ""
        }
    }

    /// The modifier mask for use with `NSMenuItem.keyEquivalentModifierMask`.
    var menuKeyEquivalentModifierMask: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    private static let keyCodeMap: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
        51: "Delete", 53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "⌦",
        120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

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

