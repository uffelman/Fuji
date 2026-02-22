//
//  DebugSettings.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/8/26.
//

import Foundation

/// Namespace for developer-only settings that are compiled out of release builds.
///
/// All members of this type are guarded by `#if DEBUG` at every call site, so
/// none of this logic is present in an Archive / App Store build.
#if DEBUG
enum DebugSettings {

    /// `UserDefaults` key that stores the "always show onboarding" preference.
    private static let forceOnboardingKey = "debug_forceOnboarding"

    /// Whether the onboarding window should be shown at every launch.
    static var alwaysShowOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: forceOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: forceOnboardingKey) }
    }
}
#endif
