//
//  Bundle+AppName.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/20/26.
//

import Foundation

extension Bundle {
    
    /// The app's name for display to the user.
    ///
    /// CFBundleName — short app name (what you set in target settings)
    /// CFBundleDisplayName — the user-facing display name (set separately, shown under the app icon); falls back to CFBundleName if not set
    var appName: String {
        infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "This App"
    }
    
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var minimumOSVersion: String {
        if let minVersion = infoDictionary?["LSMinimumSystemVersion"] as? String {
            return String(localized: .bundleMinimumOSRequired(minVersion))
        }
        // Fallback to compile-time minimum deployment target
        if #available(macOS 26.0, *) {
            return String(localized: .bundleMinimumOSFallback)
        }
        return String(localized: .bundleMinimumOSUnknown)
    }
}
