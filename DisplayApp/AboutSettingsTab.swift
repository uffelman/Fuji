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
/// along with metadata, link buttons, and a tip jar.
struct AboutSettingsTab: View {

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // App icon
                let iconSize: CGFloat = 140
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(.rect(cornerRadius: 18 / 80 * iconSize, style: .continuous))
                    .shadow(color: .accentColor.opacity(0.2), radius: 10, y: 4)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, -10)
                
                VStack(alignment: .leading) {
                    // App name
                    Text(Bundle.main.appName)
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom, 4)

                    // Version + build
                    Text("Version \(Bundle.main.appVersion) (Build \(Bundle.main.buildNumber))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)

                    // Description
                    Text("A lightweight menu bar utility for instantly \nswitching display resolutions on macOS.")
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 20)
                }
            }

            // Divider
            Divider()
                .padding(.bottom, 16)

            // Metadata grid
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    AboutMetaItem(label: "Developer", value: "Stephen Uffelman")
                    AboutMetaItem(label: "macOS", value: Bundle.main.minimumOSVersion)
                    AboutMetaItem(label: "License", value: "MIT")
                }
            }
            .padding(.bottom, 20)

            // Link buttons
            HStack(spacing: 10) {
                AboutLinkButton("Source Code", url: "https://github.com/placeholder/DisplayApp")
                AboutLinkButton("Developer Website", url: "https://stephenu.com")
            }
            .padding(.bottom, 20)

            // Tip jar
            VStack(spacing: 12) {
                Text("\(Bundle.main.appName) is free and open source.\nIf you find it useful, consider leaving a tip! ❤️")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                AboutLinkButton("Support on Ko-fi", url: "https://ko-fi.com/stephenu")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A custom link button styled to match the About tab design.
///
/// Renders as a tinted squircle pill with accent-colored text and a
/// subtle accent background + border, matching the HTML mockup.
private struct AboutLinkButton: View {
    let title: String
    let url: URL

    @State private var isHovered = false

    init(_ title: String, url: String) {
        self.title = title
        self.url = URL(string: url)!
    }

    var body: some View {
        Link(destination: url) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .foregroundStyle(Color.accentColor)
                .background(
                    Color.accentColor.opacity(isHovered ? 0.14 : 0.08),
                    in: .rect(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// A single metadata item for the About tab's info grid.
private struct AboutMetaItem: View {
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
    AboutSettingsTab()
}
