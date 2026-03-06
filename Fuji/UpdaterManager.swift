//
//  UpdaterManager.swift
//  Fuji
//

import Foundation
import Sparkle

/// Manages Sparkle auto-update functionality.
///
/// Wraps `SPUStandardUpdaterController` to provide update checking capabilities.
/// Initialized once at app startup via `Container` and wired to the menu bar
/// "Check for Updates…" item.
@MainActor
final class UpdaterManager {

    /// The Sparkle updater controller managing the update lifecycle.
    ///
    /// Initialized with `startingUpdater: true` to begin automatic background
    /// update checks according to the user's preference.
    let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Whether the user can currently trigger a manual update check.
    ///
    /// Returns false while an update session is already in progress.
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
}
