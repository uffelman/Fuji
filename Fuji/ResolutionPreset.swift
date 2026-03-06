//
//  ResolutionPreset+Application.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/7/26.
//

import Foundation
import CoreGraphics
import OSLog

/// A saved preset containing display configurations and an optional keyboard shortcut.
///
/// Presets allow users to quickly switch between predefined display arrangements.
/// Each preset can configure one or more displays and be triggered via keyboard shortcut.
struct ResolutionPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var configurations: [DisplayConfiguration]
    var keyboardShortcut: KeyboardShortcut?

    init(name: String, configurations: [DisplayConfiguration], keyboardShortcut: KeyboardShortcut? = nil) {
        self.id = UUID()
        self.name = name
        self.configurations = configurations
        self.keyboardShortcut = keyboardShortcut
    }

    /// Intelligently matches stored display configurations to current displays.
    ///
    /// This method handles cases where display IDs change after system restart by attempting
    /// multiple matching strategies:
    /// 1. Direct ID match (preferred)
    /// 2. Mode availability matching on unclaimed displays (handles ID changes)
    ///
    /// Displays that cannot be matched are skipped, allowing partial preset application
    /// when some displays are disconnected. Returns nil only when no displays match at all.
    ///
    /// - Parameter displayManager: The display manager with current display information
    /// - Returns: An array of matched configurations, or nil if no displays could be matched
    @MainActor
    func matchConfigurations(to displayManager: any DisplayManaging) -> [(displayID: CGDirectDisplayID, mode: DisplayMode)]? {
        var configurations: [(displayID: CGDirectDisplayID, mode: DisplayMode)] = []
        var claimedDisplayIDs: Set<CGDirectDisplayID> = []

        for config in self.configurations {
            let storedDisplayID = CGDirectDisplayID(config.displayID)
            
            // First, try to find the display with the stored ID
            if let display = displayManager.displays.first(where: { $0.id == storedDisplayID }) {
                configurations.append((displayID: display.id, mode: config.mode))
                claimedDisplayIDs.insert(display.id)
                Logger.app.info("Matched preset display \(storedDisplayID) directly")
            } else {
                // Display ID changed — find an unclaimed display that supports this mode
                Logger.app.info("Display ID \(storedDisplayID) not found, attempting to match by mode availability...")

                if let display = displayManager.displays.first(where: {
                    !claimedDisplayIDs.contains($0.id)
                        && $0.modes.contains(where: { $0 == config.mode })
                }) {
                    Logger.app.info("Matched display by available mode: \(display.name) (ID: \(display.id))")
                    configurations.append((displayID: display.id, mode: config.mode))
                    claimedDisplayIDs.insert(display.id)
                } else {
                    Logger.app.info("Skipping unmatched display for mode: \(config.mode.displayString)")
                }
            }
        }
        
        return configurations.isEmpty ? nil : configurations
    }
}
