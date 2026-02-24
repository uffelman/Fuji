//
//  Display.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/19/26.
//

import CoreGraphics
import Foundation

/// Represents a physical display connected to the system.
///
/// Contains information about the display's identity, capabilities, available modes,
/// and current configuration. The display ID is unique and assigned by the system.
struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let isMain: Bool
    var modes: [DisplayMode]
    var currentMode: DisplayMode?
    var defaultMode: DisplayMode?

    /// A human-readable label for the display including its status indicators.
    ///
    /// Appends "(Main)" if this is the main display and "- Built-in" if it's the built-in display.
    var displayLabel: String {
        var label = name
        if isMain {
            label += " (Main)"
        }
        if isBuiltIn {
            label += " - Built-in"
        }
        return label
    }

    /// Checks if the given mode is the default mode for this display.
    ///
    /// The default mode is typically the display's native resolution with optimal scaling.
    /// - Parameter mode: The display mode to check
    /// - Returns: `true` if the mode matches the display's default mode
    func isDefaultMode(_ mode: DisplayMode) -> Bool {
        guard let defaultMode = defaultMode else { return false }
        return mode.width == defaultMode.width && mode.height == defaultMode.height
            && mode.refreshRate == defaultMode.refreshRate && mode.isHiDPI == defaultMode.isHiDPI
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Display, rhs: Display) -> Bool {
        return lhs.id == rhs.id
    }
}
