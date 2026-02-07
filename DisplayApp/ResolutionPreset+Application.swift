//
//  ResolutionPreset+Application.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/7/26.
//

import Foundation
import CoreGraphics

extension ResolutionPreset {
    /// Intelligently match stored display configurations to current displays
    /// This handles cases where display IDs change after restart
    func matchConfigurations(to displayManager: DisplayManager) -> [(displayID: CGDirectDisplayID, mode: DisplayMode)]? {
        var configurations: [(displayID: CGDirectDisplayID, mode: DisplayMode)] = []
        
        for config in self.configurations {
            let storedDisplayID = CGDirectDisplayID(config.displayID)
            
            // First, try to find the display with the stored ID
            if let display = displayManager.displays.first(where: { $0.id == storedDisplayID }) {
                configurations.append((displayID: display.id, mode: config.mode))
                print("✓ Matched preset display \(storedDisplayID) directly")
            } else {
                // Display ID changed - try to find a matching display by characteristics
                print("⚠️ Display ID \(storedDisplayID) not found, attempting to match by characteristics...")
                
                // If there's only one display, use it
                if displayManager.displays.count == 1 {
                    let display = displayManager.displays[0]
                    print("  → Using only available display: \(display.name) (ID: \(display.id))")
                    configurations.append((displayID: display.id, mode: config.mode))
                } else {
                    // Multiple displays - try to match by checking if the mode exists
                    var foundMatch = false
                    for display in displayManager.displays {
                        // Check if this display has the requested mode
                        if display.modes.contains(where: { $0 == config.mode }) {
                            print("  → Matched display by available mode: \(display.name) (ID: \(display.id))")
                            configurations.append((displayID: display.id, mode: config.mode))
                            foundMatch = true
                            break
                        }
                    }
                    
                    if !foundMatch {
                        print("  ✗ Could not find matching display for mode: \(config.mode.displayString)")
                        return nil
                    }
                }
            }
        }
        
        return configurations
    }
}
