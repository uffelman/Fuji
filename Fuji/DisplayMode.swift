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
    let id: UUID
    let modeNumber: Int
    let width: Int
    let height: Int
    let refreshRate: Double
    let isHiDPI: Bool
    let bitDepth: Int

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
        case id, modeNumber, width, height, refreshRate, isHiDPI, bitDepth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.modeNumber = try container.decode(Int.self, forKey: .modeNumber)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
        self.refreshRate = try container.decode(Double.self, forKey: .refreshRate)
        self.isHiDPI = try container.decode(Bool.self, forKey: .isHiDPI)
        self.bitDepth = try container.decode(Int.self, forKey: .bitDepth)
        self.aspectRatioLabel = Self.computeAspectRatioLabel(width: width, height: height)
    }

    init(
        modeNumber: Int, width: Int, height: Int, refreshRate: Double, isHiDPI: Bool,
        bitDepth: Int
    ) {
        self.id = UUID()
        self.modeNumber = modeNumber
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
        self.isHiDPI = isHiDPI
        self.bitDepth = bitDepth
        self.aspectRatioLabel = Self.computeAspectRatioLabel(width: width, height: height)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(refreshRate)
        hasher.combine(isHiDPI)
    }

    /// Implements custom equality comparison for display modes.
    ///
    /// Two modes are considered equal if they have matching width, height, refresh rate (within 0.01Hz tolerance),
    /// and HiDPI status. This accounts for floating-point precision issues with refresh rates.
    static func == (lhs: DisplayMode, rhs: DisplayMode) -> Bool {
        // Use epsilon comparison for refresh rate due to floating point precision issues
        let refreshRateMatch = abs(lhs.refreshRate - rhs.refreshRate) < 0.01
        return lhs.width == rhs.width && lhs.height == rhs.height
            && refreshRateMatch && lhs.isHiDPI == rhs.isHiDPI
    }
}
