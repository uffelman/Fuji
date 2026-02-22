//
//  OnboardingView.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/8/26.
//

import AppKit
import SwiftUI

// MARK: - Root onboarding view

/// The full onboarding experience, presented as a two-page flow.
///
/// Page 1 — Welcome: introduces the app and its core concepts.
/// Page 2 — Permissions: shows live accessibility permission status and guides
///           the user to grant it with minimal friction.
///
/// When `startOnPage` is `1`, the welcome page is skipped entirely and the page
/// indicator is hidden, so the user sees only the permissions screen.
struct OnboardingView: View {

    // Injected so the window can react to the user closing the flow.
    let onDismiss: (() -> Void)?
    
    /// Called just before the system permission prompt is triggered, giving the
    /// window controller a chance to lower its window level so the dialog is visible.
    let onWillRequestPermission: (() -> Void)?

    /// Provides permission state without coupling the view to system APIs.
    let permissions: any PermissionsManaging

    /// The page index to begin on. Pass `1` to skip straight to the permissions page.
    let startOnPage: Int

    /// Called whenever the rendered height of the current page changes.
    /// The window controller uses this to resize the window from AppKit's side,
    /// avoiding any layout-cycle feedback between SwiftUI and NSWindow.
    var onHeightChanged: ((CGFloat) -> Void)? = nil

    @State private var currentPage: Int = 0

    // When the flow starts on page 1, there is effectively only a single page
    // to show, so the indicator dots are meaningless and should be hidden.
    private var showPageIndicator: Bool { startOnPage == 0 }

    // Computed shorthand so child views and the footer can read permission
    // state directly from the injected manager.
    private var hasPermission: Bool { permissions.isAccessibilityTrusted }

    var body: some View {
        VStack(spacing: 0) {
            // ── Page content ──────────────────────────────────────────────
            Group {
                if currentPage == 0 {
                    WelcomePage()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal:   .move(edge: .leading)
                        ))
                } else {
                    PermissionsPage(
                        permissions: permissions,
                        onDismiss: onDismiss,
                        onWillRequestPermission: onWillRequestPermission
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .trailing)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentPage)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: _HeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(_HeightKey.self) { h in
                guard h > 0 else { return }
                onHeightChanged?(h)
            }

            Divider()

            // ── Navigation footer ─────────────────────────────────────────
            HStack {
                // Page indicator dots — only shown in the full two-page flow
                if showPageIndicator {
                    HStack(spacing: 6) {
                        ForEach(0..<2) { index in
                            Circle()
                                .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.35))
                                .frame(width: 7, height: 7)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                }

                Spacer()

                if currentPage == 0 {
                    PillButton("Continue", style: .accent) {
                        currentPage = 1
                    }
                    .keyboardShortcut(.return, modifiers: [])
                } else {
                    if hasPermission {
                        PillButton("Done", style: .accent) {
                            onDismiss?()
                        }
                        .keyboardShortcut(.return, modifiers: [])
                    } else {
                        PillButton("Skip for Now", style: .monochrome) {
                            onDismiss?()
                        }
                        .keyboardShortcut(.return, modifiers: [])
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(.background)
        }
        .onAppear {
            // Jump straight to the requested start page without any animation,
            // since there is nothing to transition away from on first appear.
            currentPage = startOnPage
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 0) {
            // Hero area
            VStack(spacing: 14) {
                Image(systemName: "display.2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                Text("Welcome to DisplayApp")
                    .font(.system(size: 22, weight: .bold))

                Text("Instantly switch between display resolutions from your menu bar.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 36)
            .padding(.horizontal, 40)

            // Feature list
            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(
                    icon: "rectangle.stack.fill",
                    color: .blue,
                    title: "Resolution Presets",
                    description: "Save and name your favourite display configurations for one-click switching."
                )
                FeatureRow(
                    icon: "keyboard",
                    color: .purple,
                    title: "Global Keyboard Shortcuts",
                    description: "Assign hotkeys to presets so you can change resolution without touching the mouse."
                )
                FeatureRow(
                    icon: "menubar.rectangle",
                    color: .green,
                    title: "Lives in Your Menu Bar",
                    description: "DisplayApp stays out of your way — always available from the menu bar, never cluttering your Dock."
                )
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Page 2: Permissions

private struct PermissionsPage: View {
    let permissions: any PermissionsManaging
    let onDismiss: (() -> Void)?
    let onWillRequestPermission: (() -> Void)?

    private var hasPermission: Bool { permissions.isAccessibilityTrusted }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image(systemName: hasPermission ? "checkmark.shield.fill" : "lock.shield")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 66, height: 66)
                    .foregroundStyle(hasPermission ? .green : .orange)
                    .symbolRenderingMode(.hierarchical)
                    .animation(.easeInOut(duration: 0.3), value: hasPermission)

                Text("Accessibility Permission")
                    .font(.system(size: 22, weight: .bold))

                Text("Global keyboard shortcuts need **Accessibility** access so DisplayApp can respond to hotkeys even when another app is in focus.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 32)
            .padding(.horizontal, 40)

            // Status card
            PermissionStatusCard(hasPermission: hasPermission)
                .padding(.horizontal, 36)
                .padding(.top, 20)
                .padding(.bottom, hasPermission ? 12 : 0)

            if !hasPermission {
                // Primary CTA — triggers the system permission prompt on demand.
                PillButton("Allow Access…", systemImage: "lock.open.fill", style: .accent) {
                    onWillRequestPermission?()
                    permissions.requestAccessibilityPermission()
                }
                .padding(.top, 16)

                // Fallback guide shown when the user needs to enable access manually
                // (e.g. they dismissed the system prompt or it didn't appear).
                VStack(alignment: .leading, spacing: 10) {
                    Text("Or grant access manually:")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.bottom, 2)

                    StepRow(number: 1, text: "Click **Open System Settings** below.")
                    StepRow(number: 2, text: "Scroll to find **DisplayApp** in the list.")
                    StepRow(number: 3, text: "Toggle the switch next to DisplayApp to **on**.")
                    StepRow(number: 4, text: "Return here — permission status updates automatically.")
                }
                .padding(.horizontal, 36)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                PillButton("Open System Settings", systemImage: "gear", style: .monochrome) {
                    permissions.openAccessibilitySettings()
                }
                .padding(.top, 14)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Supporting sub-views

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PermissionStatusCard: View {
    let hasPermission: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(hasPermission ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasPermission ? "Permission granted" : "Permission not granted")
                    .font(.system(size: 13.5, weight: .medium))
                Text(
                    hasPermission
                        ? "Global keyboard shortcuts are active and ready to use."
                        : "Keyboard shortcuts will not work until this is enabled."
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            (hasPermission ? Color.green : Color.orange).opacity(0.08)
        )
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    (hasPermission ? Color.green : Color.orange).opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

private struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor)
                .clipShape(Circle())
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Internal preference key for height measurement

private struct _HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Always take the latest value, not the max — so shrinking pages
        // correctly report a smaller height rather than staying at the peak.
        value = nextValue()
    }
}

#Preview("Permissions – not granted") {
    PermissionsPage(
        permissions: MockPermissionsManager.previewUntrusted,
        onDismiss: nil,
        onWillRequestPermission: nil
    )
}
#Preview("Permissions – granted") {
    PermissionsPage(
        permissions: MockPermissionsManager.previewTrusted,
        onDismiss: nil,
        onWillRequestPermission: nil
    )
}

#Preview("Full onboarding flow") {
    OnboardingView(
        onDismiss: nil,
        onWillRequestPermission: nil,
        permissions: MockPermissionsManager.previewUntrusted,
        startOnPage: 0
    )
}
