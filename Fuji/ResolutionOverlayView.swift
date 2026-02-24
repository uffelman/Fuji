//
//  ResolutionOverlayView.swift
//  Fuji
//

import SwiftUI

/// A single line of overlay content representing one display's resolution change.
struct OverlayLine: Identifiable {
    let id = UUID()
    let displayName: String
    let resolution: String
}

/// The SwiftUI view displayed inside the resolution change overlay window.
///
/// Shows the new resolution after a display mode switch, styled as a dark translucent HUD
/// similar to the macOS volume/brightness overlay.
struct ResolutionOverlayView: View {
    let presetName: String?
    let lines: [OverlayLine]

    init(lines: [OverlayLine], presetName: String? = nil) {
        self.lines = lines
        self.presetName = presetName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let presetName {
                Text(presetName)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            ForEach(lines) { line in
                HStack(spacing: 10) {
                    Image(systemName: "display")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 2) {
                        if lines.count > 1 || presetName != nil {
                            Text(line.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Text(line.resolution)
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .fixedSize()
        .background {
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.45)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }
}
