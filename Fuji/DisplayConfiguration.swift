//
//  DisplayConfiguration.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/15/26.
//

import CoreGraphics
import Foundation

/// Represents a display resolution configuration for a specific display.
///
/// Links a display (by ID) with a desired display mode. Used when saving and applying
/// resolution presets that may affect multiple displays.
struct DisplayConfiguration: Codable, Identifiable, Hashable {
    let id: UUID
    let displayID: UInt32
    let mode: DisplayMode

    init(displayID: CGDirectDisplayID, mode: DisplayMode) {
        self.id = UUID()
        self.displayID = displayID
        self.mode = mode
    }
}
