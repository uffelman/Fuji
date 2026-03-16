//
//  PillButton.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/20/26.
//

import SwiftUI

/// A custom squircle pill button with a tinted background and subtle border.
///
/// Supports two visual styles via ``PillButtonStyle``:
/// - **accent** — accent-colored text on a light accent fill (matches the About tab links).
/// - **monochrome** — primary-colored text on a neutral fill (matches secondary actions).
///
/// The button can wrap either a `Link` (when a `url` is provided) or a plain `Button`
/// (when an `action` closure is provided).
///
/// ```swift
/// // Link variant (accent)
/// PillButton(.aboutSourceCode, style: .accent, url: "https://github.com/...")
///
/// // Action variant (monochrome)
/// PillButton(.presetEditorRecordShortcut, style: .monochrome) { startRecording() }
///
/// // With a leading SF Symbol
/// PillButton(.onboardingAllowAccess, systemImage: "lock.open.fill", style: .accent) { requestAccess() }
/// ```
struct PillButton: View {
    let title: LocalizedStringResource
    let systemImage: String?
    let style: PillButtonStyle
    private let destination: URL?
    private let action: (() -> Void)?

    @State private var isHovered = false

    /// Creates a pill button that opens a URL.
    init(_ title: LocalizedStringResource, systemImage: String? = nil, style: PillButtonStyle = .accent, url: String) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.destination = URL(string: url)
        self.action = nil
    }

    /// Creates a pill button that performs an action.
    init(_ title: LocalizedStringResource, systemImage: String? = nil, style: PillButtonStyle = .accent, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.destination = nil
        self.action = action
    }

    private var tintColor: Color {
        switch style {
        case .accent: Color.accentColor
        case .monochrome: Color.primary
        }
    }

    private var fillOpacity: Double {
        isHovered ? 0.14 : 0.08
    }

    private var borderOpacity: Double {
        switch style {
        case .accent: 0.15
        case .monochrome: 0.12
        }
    }

    var body: some View {
        Group {
            if let destination {
                Link(destination: destination) {
                    label
                }
            } else if let action {
                Button(action: action) {
                    label
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var label: some View {
        Group {
            if let systemImage {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImage)
                }
            } else {
                Text(title)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .foregroundStyle(tintColor)
        .background(
            tintColor.opacity(fillOpacity),
            in: .rect(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tintColor.opacity(borderOpacity), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        VStack(spacing: 8) {
            Text("Accent (.accent)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                PillButton(.aboutSourceCode, style: .accent, url: "https://github.com/uffelman/Fuji")
                PillButton(.aboutDeveloperWebsite, style: .accent, url: "https://stephenu.com")
            }
        }

        Divider()

        VStack(spacing: 8) {
            Text("Monochrome (.monochrome)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                PillButton(.presetEditorRecordShortcut, style: .monochrome) {}
                PillButton(.presetEditorCancel, style: .monochrome) {}
            }
        }

        Divider()

        VStack(spacing: 8) {
            Text("With leading image")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                PillButton(.onboardingAllowAccess, systemImage: "lock.open.fill", style: .accent) {}
                PillButton(.onboardingOpenSystemSettings, systemImage: "gear", style: .monochrome) {}
            }
        }
    }
    .padding(24)
}

/// The color scheme for a ``PillButton``.
///
/// - ``accent``: Uses the system accent color (blue) for tint, fill, and border.
/// - ``monochrome``: Uses the primary label color, producing a neutral gray appearance
///   that adapts to light and dark mode.
enum PillButtonStyle {
    /// System accent color (blue). Used for link buttons on the About tab.
    case accent
    /// Neutral gray derived from the primary label color. Used for secondary
    /// actions like "Record Shortcut" in the preset editor.
    case monochrome
}
