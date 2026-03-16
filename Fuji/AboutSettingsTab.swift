//
//  AboutTab.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/19/26.
//

import SwiftUI

/// The about tab showing app information.
///
/// Displays the app name, version, icon, build number, and description,
/// along with metadata, link buttons, and a tip jar.
struct AboutSettingsTab: View {

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                // App icon
                let iconSize: CGFloat = 120
                Image("AppIconDisplay")
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(.rect(cornerRadius: 18 / 80 * iconSize, style: .continuous))
                    .shadow(color: .accentColor.opacity(0.2), radius: 10, y: 4)
                    .frame(maxHeight: .infinity, alignment: .top)
                
                VStack(alignment: .leading) {
                    // App name
                    Text(Bundle.main.appName)
                        .font(.system(size: 24, weight: .bold))
                        .padding(.bottom, 4)

                    // Version
                    Text(.aboutVersion(Bundle.main.appVersion))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)

                    // Description
                    Text(.aboutDescription)
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 20)
                }
                .offset(y: 8)
            }

            // Divider
            Divider()
                .padding(.bottom, 16)

            // Metadata grid
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    AboutMetaItem(label: .aboutMetaDeveloper, value: "Stephen Uffelman")
                    AboutMetaItem(label: .aboutMetaMacOS, value: Bundle.main.minimumOSVersion)
                    AboutMetaItem(label: .aboutMetaLicense, value: "AGPL v3")
                }
            }
            .padding(.bottom, 20)

            // Link buttons
            HStack(spacing: 10) {
                PillButton(.aboutSourceCode, style: .accent, url: "https://github.com/uffelman/Fuji")
                PillButton(.aboutDeveloperWebsite, style: .accent, url: "https://stephenu.com")
            }
            .padding(.bottom, 20)

            // Tip jar
            VStack(spacing: 12) {
                Text(.aboutTipJarText(Bundle.main.appName))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                PillButton(.aboutSupportKofi, style: .accent, url: "https://ko-fi.com/stephenu")
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

/// A single metadata item for the About tab's info grid.
private struct AboutMetaItem: View {
    let label: LocalizedStringResource
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
        .frame(
            width: SettingsViewMetrics.size.width,
            height: SettingsViewMetrics.size.height
        )
}
