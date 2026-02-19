//
//  AboutTab.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/19/26.
//

import Foundation
import SwiftUI

/// The about tab showing app information.
///
/// Displays the app name, version, icon, build number, and description,
/// along with metadata and link buttons.
struct AboutTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var minimumOSVersion: String {
        if let minVersion = Bundle.main.infoDictionary?["LSMinimumSystemVersion"] as? String {
            return "\(minVersion)+ Required"
        }
        // Fallback to compile-time minimum deployment target
        if #available(macOS 26.0, *) {
            return "26.0+ Required"
        }
        return "Unknown"
    }

    var body: some View {
        VStack(spacing: 0) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(.rect(cornerRadius: 18))
                .shadow(color: .accentColor.opacity(0.2), radius: 10, y: 4)
                .padding(.bottom, 14)

            // App name
            Text("DisplayApp")
                .font(.system(size: 20, weight: .bold))
                .padding(.bottom, 4)

            // Version + build
            Text("Version \(appVersion) (Build \(buildNumber))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)

            // Description
            Text("A lightweight menu bar utility for instantly switching display resolutions on macOS.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.bottom, 20)

            // Divider
            Divider()
                .padding(.bottom, 16)

            // Metadata grid
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    AboutMetaItem(label: "Developer", value: "Stephen Uffelman")
                    AboutMetaItem(label: "License", value: "Single User")
                }
                GridRow {
                    AboutMetaItem(label: "macOS", value: minimumOSVersion)
                    AboutMetaItem(label: "Framework", value: "SwiftUI")
                }
            }
            .padding(.bottom, 20)

            // Link buttons
            HStack(spacing: 10) {
                Button("Acknowledgements") {}
                    .buttonStyle(.bordered)
                    .tint(.accentColor)

                Button("Privacy Policy") {}
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single metadata item for the About tab's info grid.
struct AboutMetaItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold).smallCaps())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13))
        }
    }
}

#Preview {
    AboutTab()
}
