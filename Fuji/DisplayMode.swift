//
//  DisplayMode.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/19/26.
//

import Foundation

/// Represents a single display mode (resolution) that a display can support.
///
/// Each mode includes dimensions, refresh rate, HiDPI status, and bit depth.
/// Display modes are uniquely identified and can be compared for equality based on their properties.
struct DisplayMode: Identifiable, Hashable, Codable {
    let bitDepth: Int
    let height: Int
    let isHiDPI: Bool
    let modeNumber: Int
    let refreshRate: Double
    let width: Int

    /// A deterministic identifier derived from the mode's display properties.
    var id: String { "\(width)x\(height)@\(refreshRate)_\(isHiDPI)" }

    /// The aspect ratio label if it matches a common desktop ratio (e.g. "16:9"), or nil.
    ///
    /// Computed once at init time. Only returns a value for these common ratios:
    /// 16:9, 16:10, 4:3, 21:9, 9:16, 1:1, 5:4, 3:2
    let aspectRatioLabel: String?

    /// A human-readable string representation of the display mode with full details.
    ///
    /// Includes resolution, refresh rate, and HiDPI status.
    /// Example: "1920 × 1080 @ 60Hz (HiDPI)"
    var displayString: String {
        let hiDPILabel = isHiDPI ? " (HiDPI)" : ""
        let refreshString = refreshRate > 0 ? " @ \(Int(refreshRate))Hz" : ""
        return "\(width) × \(height)\(refreshString)\(hiDPILabel)"
    }

    /// A short string representation showing only the resolution.
    ///
    /// Example: "1920×1080"
    var shortDisplayString: String {
        return "\(width)×\(height)"
    }

    /// Common desktop aspect ratios used to determine `aspectRatioLabel`.
    private static let commonRatios: [(w: Int, h: Int, label: String)] = [
        (16, 9, "16:9"),
        (16, 10, "16:10"),
        (4, 3, "4:3"),
        (21, 9, "21:9"),
        (9, 16, "9:16"),
        (1, 1, "1:1"),
        (5, 4, "5:4"),
        (3, 2, "3:2"),
    ]

    /// Computes the aspect ratio label for the given dimensions.
    ///
    /// First tries exact GCD match, then falls back to approximate floating-point
    /// comparison to handle resolutions like 1366×768 (≈16:9).
    private static func computeAspectRatioLabel(width: Int, height: Int) -> String? {
        guard width > 0 && height > 0 else { return nil }
        let g = gcd(width, height)
        let rw = width / g
        let rh = height / g
        // Exact match
        if let label = commonRatios.first(where: { $0.w == rw && $0.h == rh })?.label {
            return label
        }
        // Approximate match (tolerance of 1%)
        let ratio = Double(width) / Double(height)
        for entry in commonRatios {
            let target = Double(entry.w) / Double(entry.h)
            if abs(ratio - target) / target < 0.01 {
                return entry.label
            }
        }
        return nil
    }

    /// Computes the greatest common divisor of two integers.
    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    private enum CodingKeys: String, CodingKey {
        case bitDepth
        case height
        case isHiDPI
        case modeNumber
        case refreshRate
        case width
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bitDepth = try container.decode(Int.self, forKey: .bitDepth)
        self.height = try container.decode(Int.self, forKey: .height)
        self.isHiDPI = try container.decode(Bool.self, forKey: .isHiDPI)
        self.modeNumber = try container.decode(Int.self, forKey: .modeNumber)
        self.refreshRate = try container.decode(Double.self, forKey: .refreshRate)
        self.width = try container.decode(Int.self, forKey: .width)
        self.aspectRatioLabel = Self.computeAspectRatioLabel(width: width, height: height)
    }

    init(
        modeNumber: Int,
        width: Int,
        height: Int,
        refreshRate: Double,
        isHiDPI: Bool,
        bitDepth: Int
    ) {
        self.modeNumber = modeNumber
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
        self.isHiDPI = isHiDPI
        self.bitDepth = bitDepth
        self.aspectRatioLabel = Self.computeAspectRatioLabel(width: width, height: height)
    }

    /// Returns whether this mode has the same aspect ratio as another mode.
    ///
    /// Uses approximate comparison with 1% tolerance to handle non-exact resolutions
    /// like 1366×768 (≈16:9), matching the convention used for `aspectRatioLabel`.
    func hasSameAspectRatio(as other: DisplayMode) -> Bool {
        guard width > 0 && height > 0 && other.width > 0 && other.height > 0 else { return false }
        let ratio = Double(width) / Double(height)
        let otherRatio = Double(other.width) / Double(other.height)
        return abs(ratio - otherRatio) / max(ratio, otherRatio) < 0.01
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(height)
        hasher.combine(isHiDPI)
        hasher.combine(refreshRate)
        hasher.combine(width)
    }

    /// Implements custom equality comparison for display modes.
    ///
    /// Two modes are considered equal if they have matching width, height, refresh rate (within 0.01Hz tolerance),
    /// and HiDPI status. This accounts for floating-point precision issues with refresh rates.
    static func == (lhs: DisplayMode, rhs: DisplayMode) -> Bool {
        // Use epsilon comparison for refresh rate due to floating point precision issues
        let refreshRateMatch = abs(lhs.refreshRate - rhs.refreshRate) < 0.01
        return lhs.height == rhs.height
            && lhs.isHiDPI == rhs.isHiDPI
            && lhs.width == rhs.width
            && refreshRateMatch
    }
}
