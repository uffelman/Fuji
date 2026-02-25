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

    // MARK: - Resolution Group Navigation

    /// Returns the unique resolution groups for this display, ordered from largest to smallest.
    ///
    /// Each group contains all modes sharing the same width and height dimensions.
    /// Groups maintain the existing mode sort order (descending by width, then height).
    func uniqueResolutionGroups() -> [[DisplayMode]] {
        var groups: [[DisplayMode]] = []
        var lastWidth: Int?
        var lastHeight: Int?
        var currentGroup: [DisplayMode] = []

        for mode in modes {
            if mode.width == lastWidth && mode.height == lastHeight {
                currentGroup.append(mode)
            } else {
                if !currentGroup.isEmpty { groups.append(currentGroup) }
                currentGroup = [mode]
                lastWidth = mode.width
                lastHeight = mode.height
            }
        }
        if !currentGroup.isEmpty { groups.append(currentGroup) }

        return groups
    }

    /// Returns the best mode from the next higher resolution group.
    ///
    /// "Higher" means larger pixel dimensions. Returns nil if the current mode is already
    /// at the highest available resolution.
    func nextHigherResolution() -> DisplayMode? {
        guard let currentMode else { return nil }
        let groups = uniqueResolutionGroups()

        guard let currentIndex = groups.firstIndex(where: {
            $0.first?.width == currentMode.width && $0.first?.height == currentMode.height
        }) else { return nil }

        // Groups are sorted descending, so "higher" is at a lower index
        let targetIndex = currentIndex - 1
        guard targetIndex >= 0 else { return nil }

        return bestMode(in: groups[targetIndex], matching: currentMode)
    }

    /// Returns the best mode from the next lower resolution group.
    ///
    /// "Lower" means smaller pixel dimensions. Returns nil if the current mode is already
    /// at the lowest available resolution.
    func nextLowerResolution() -> DisplayMode? {
        guard let currentMode else { return nil }
        let groups = uniqueResolutionGroups()

        guard let currentIndex = groups.firstIndex(where: {
            $0.first?.width == currentMode.width && $0.first?.height == currentMode.height
        }) else { return nil }

        // Groups are sorted descending, so "lower" is at a higher index
        let targetIndex = currentIndex + 1
        guard targetIndex < groups.count else { return nil }

        return bestMode(in: groups[targetIndex], matching: currentMode)
    }

    /// Selects the best mode from a group, preferring the same HiDPI status and highest refresh rate.
    ///
    /// - Parameters:
    ///   - group: The array of modes in the target resolution group
    ///   - reference: The current mode used to determine HiDPI preference
    /// - Returns: The best matching mode, or nil if the group is empty
    private func bestMode(in group: [DisplayMode], matching reference: DisplayMode) -> DisplayMode? {
        guard !group.isEmpty else { return nil }

        // First try: same HiDPI status, highest refresh rate
        let sameHiDPI = group
            .filter { $0.isHiDPI == reference.isHiDPI }
            .max { $0.refreshRate < $1.refreshRate }

        if let match = sameHiDPI {
            return match
        }

        // Fallback: any mode with highest refresh rate
        return group.max { $0.refreshRate < $1.refreshRate }
    }

    // MARK: - Hashable & Equatable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Display, rhs: Display) -> Bool {
        return lhs.id == rhs.id
    }
}
