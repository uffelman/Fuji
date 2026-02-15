//
//  PermissionsManager.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/8/26.
//

import AppKit
import Foundation

// MARK: - Protocol

/// Abstracts accessibility-permission queries so that views and managers never
/// call system APIs directly.
///
/// Conformers are responsible for:
/// - Reporting the current trusted state via ``isAccessibilityTrusted``
/// - Optionally showing the system prompt that adds the app to the Accessibility
///   list in System Settings via ``requestAccessibilityPermission()``
/// - Opening the Accessibility pane in System Settings via
///   ``openAccessibilitySettings()``
@MainActor
protocol PermissionsManaging: AnyObject, Observable {
    /// `true` when the process has been granted Accessibility permission.
    var isAccessibilityTrusted: Bool { get }

    /// Prompts the user to add the app to the Accessibility list.
    ///
    /// On the real implementation this calls `AXIsProcessTrustedWithOptions`
    /// with `kAXTrustedCheckOptionPrompt = true`.  The mock implementation is
    /// a no-op.
    func requestAccessibilityPermission()

    /// Opens the Accessibility pane inside System Settings.
    func openAccessibilitySettings()
}

// MARK: - Real implementation

/// The production ``PermissionsManaging`` implementation.
///
/// Instantiate exactly once — in `AppDelegate` — and inject the resulting
/// object wherever permission state is needed.
///
/// Permission state is polled on a background `Task` so that the published
/// property stays up to date while an onboarding window is open.
@Observable
@MainActor
final class PermissionsManager: PermissionsManaging {

    /// `true` when `AXIsProcessTrusted()` returns `true`.
    ///
    /// SwiftUI views that receive this object via the environment will
    /// automatically redraw when this value changes.
    private(set) var isAccessibilityTrusted: Bool = AXIsProcessTrusted()

    /// How often (in seconds) the manager re-checks `AXIsProcessTrusted()`.
    private let pollingInterval: Duration

    private var pollingTask: Task<Void, Never>?

    /// - Parameter pollingInterval: The interval between permission checks.
    ///   Defaults to 1.5 s, which is responsive without hammering the system.
    init(pollingInterval: Duration = .seconds(1.5)) {
        self.pollingInterval = pollingInterval
        startPolling()
    }

    deinit {
        MainActor.assumeIsolated {
            pollingTask?.cancel()
        }
    }

    // MARK: PermissionsManaging

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // Refresh immediately so callers see the result without waiting for the
        // next polling tick.
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Private

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                let trusted = AXIsProcessTrusted()
                if trusted != self.isAccessibilityTrusted {
                    self.isAccessibilityTrusted = trusted
                }
            }
        }
    }
}

// MARK: - Mock (previews & tests)

/// A non-system, fully controllable stand-in for use in SwiftUI previews and
/// unit tests.
///
/// No Accessibility API is ever called, so the system permission prompt never
/// appears in the canvas.
///
/// ```swift
/// #Preview {
///     let permissions = MockPermissionsManager(isAccessibilityTrusted: false)
///     return OnboardingView(permissions: permissions, onDismiss: {})
/// }
/// ```
@Observable
@MainActor
final class MockPermissionsManager: PermissionsManaging {

    /// Set this to drive UI state changes in previews or tests.
    var isAccessibilityTrusted: Bool

    /// Tracks whether ``requestAccessibilityPermission()`` was called.
    private(set) var didRequestPermission = false

    /// Tracks whether ``openAccessibilitySettings()`` was called.
    private(set) var didOpenSettings = false

    /// - Parameter isAccessibilityTrusted: The initial simulated permission
    ///   state. Defaults to `false` so that the "not granted" UI is shown.
    init(isAccessibilityTrusted: Bool = false) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }

    func requestAccessibilityPermission() {
        didRequestPermission = true
    }

    func openAccessibilitySettings() {
        didOpenSettings = true
    }
}
