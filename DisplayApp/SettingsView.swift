//
//  SettingsView.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import ServiceManagement
import SwiftUI

/// The main settings view for the application.
///
/// Displays a tab-based interface with sections for managing presets, general settings, and app information.
struct SettingsView: View {
    static let size = CGSize(width: 500, height: 470)
    
    let displayManager: any DisplayManaging
    let settingsManager: any SettingsManaging
    let onPresetsChanged: (() -> Void)?

    @State private var selectedTab = SettingsTab.presets
    @Namespace private var tabAnimation

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar — animation scoped here so only the pill slides,
            // not the tab content below.
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: tabAnimation
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(3)
            .background(Color(.separatorColor).opacity(0.3))
            .clipShape(.rect(cornerRadius: 9))
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Tab content — no animation here to avoid content flicker.
            Group {
                switch selectedTab {
                case .presets:
                    PresetsSettingsTab(
                        displayManager: displayManager,
                        settingsManager: settingsManager,
                        onPresetsChanged: onPresetsChanged
                    )
                case .general:
                    GeneralSettingsTab(settingsManager: settingsManager)
                case .about:
                    AboutSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 500, minHeight: 400)
    }
}

/// A single button in the custom settings tab bar.
private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(.windowBackgroundColor))
                        .shadow(color: .primary.opacity(0.08), radius: 2, y: 1)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Identifies the settings tabs.
private enum SettingsTab: Int, CaseIterable {
    case presets, general, about

    var title: String {
        switch self {
        case .presets: "Presets"
        case .general: "General"
        case .about: "About"
        }
    }
    
    var icon: String {
        switch self {
        case .presets: "display"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

/// A list row displaying a preset with its name, configuration summary, and action buttons.
struct PresetRow: View {
    let preset: ResolutionPreset
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .font(.system(size: 13.5, weight: .medium))

                Text(configurationSummary)
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let shortcut = preset.keyboardShortcut {
                Text(shortcut.displayString)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.separatorColor).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: 5))
            }

            Button("Edit", systemImage: "pencil", action: onEdit)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(.tertiary)

            Button("Delete", systemImage: "trash", action: onDelete)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(Color(.systemRed).opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// Generates a comma-separated summary of the preset's display configurations.
    private var configurationSummary: String {
        let details = preset.configurations.map { config in
            let hiDPI = config.mode.isHiDPI ? "HiDPI" : "Standard"
            return "\(hiDPI) · \(config.mode.shortDisplayString)"
        }
        return details.joined(separator: ", ")
    }
}

#Preview {
    SettingsView(
        displayManager: MockDisplayManager(),
        settingsManager: MockSettingsManager(),
        onPresetsChanged: nil
    )
}
