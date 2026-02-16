//
//  DisplayManager.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import CoreGraphics
import Foundation
import IOKit

/// Represents a single display mode (resolution) that a display can support.
///
/// Each mode includes dimensions, refresh rate, HiDPI status, and bit depth.
/// Display modes are uniquely identified and can be compared for equality based on their properties.
struct DisplayMode: Identifiable, Hashable, Codable {
    let id: UUID
    let modeNumber: Int32
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
        self.modeNumber = try container.decode(Int32.self, forKey: .modeNumber)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
        self.refreshRate = try container.decode(Double.self, forKey: .refreshRate)
        self.isHiDPI = try container.decode(Bool.self, forKey: .isHiDPI)
        self.bitDepth = try container.decode(Int.self, forKey: .bitDepth)
        self.aspectRatioLabel = Self.computeAspectRatioLabel(width: width, height: height)
    }

    init(
        modeNumber: Int32, width: Int, height: Int, refreshRate: Double, isHiDPI: Bool,
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

/// Represents a physical display connected to the system.
///
/// Contains information about the display's identity, capabilities, available modes,
/// and current configuration. The display ID is unique and assigned by the system.
struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let isMain: Bool
    var modes: [DisplayMode]
    var currentMode: DisplayMode?
    var defaultMode: DisplayMode?

    /// A human-readable label for the display including its status indicators.
    ///
    /// Appends "(Main)" if this is the main display and "- Built-in" if it's the built-in display.
    var displayLabel: String {
        var label = name
        if isMain {
            label += " (Main)"
        }
        if isBuiltIn {
            label += " - Built-in"
        }
        return label
    }

    /// Checks if the given mode is the default mode for this display.
    ///
    /// The default mode is typically the display's native resolution with optimal scaling.
    /// - Parameter mode: The display mode to check
    /// - Returns: `true` if the mode matches the display's default mode
    func isDefaultMode(_ mode: DisplayMode) -> Bool {
        guard let defaultMode = defaultMode else { return false }
        return mode.width == defaultMode.width && mode.height == defaultMode.height
            && mode.refreshRate == defaultMode.refreshRate && mode.isHiDPI == defaultMode.isHiDPI
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Display, rhs: Display) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Manages all connected displays and their resolution modes.
///
/// This class provides a centralized interface for discovering displays, querying their capabilities,
/// and changing display resolutions. It monitors for display configuration changes and maintains
/// an up-to-date list of available displays. All display operations use Core Graphics APIs.
@MainActor
@Observable
final class DisplayManager {
    static let shared = DisplayManager()

    private(set) var displays: [Display] = []
    private var displayReconfigurationCallback: CGDisplayReconfigurationCallBack?

    init() {
        refreshDisplays()
        registerForDisplayChanges()
    }

    deinit {
        unregisterDisplayChanges()
    }

    /// Queries the system for all active displays and updates the internal display list.
    ///
    /// This method retrieves up to 16 connected displays from the system and creates
    /// Display objects with their available modes and current configuration.
    func refreshDisplays() {
        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)

        let result = CGGetActiveDisplayList(16, &displayIDs, &displayCount)
        guard result == .success else {
            print("Failed to get display list: \(result)")
            return
        }

        displays = (0..<Int(displayCount)).compactMap { index in
            let displayID = displayIDs[index]
            return createDisplay(for: displayID)
        }
    }

    /// Creates a Display object for the given display ID by querying its properties.
    ///
    /// Retrieves the display's name, type (built-in or external), main display status,
    /// available modes, current mode, and default mode.
    /// - Parameter displayID: The Core Graphics display ID
    /// - Returns: A Display object, or nil if the display cannot be queried
    private func createDisplay(for displayID: CGDirectDisplayID) -> Display? {
        let name = getDisplayName(for: displayID)
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
        let isMain = CGDisplayIsMain(displayID) != 0
        let modes = getDisplayModes(for: displayID)
        let currentMode = getCurrentMode(for: displayID)
        let defaultMode = getDefaultMode(for: displayID, from: modes)

        return Display(
            id: displayID,
            name: name,
            isBuiltIn: isBuiltIn,
            isMain: isMain,
            modes: modes,
            currentMode: currentMode,
            defaultMode: defaultMode
        )
    }

    /// Determines the default "best" mode for a display based on its native panel resolution.
    ///
    /// For Retina displays, this is the HiDPI mode at half the native resolution (true 2x scaling).
    /// For non-Retina displays, this is the native resolution in 1:1 mode.
    /// - Parameters:
    ///   - displayID: The Core Graphics display ID
    ///   - modes: Available display modes for this display
    /// - Returns: The default display mode, or nil if it cannot be determined
    private func getDefaultMode(for displayID: CGDirectDisplayID, from modes: [DisplayMode])
        -> DisplayMode?
    {
        // Get native panel resolution by analyzing available display modes
        guard let nativePanelResolution = getNativePanelResolution(for: displayID) else {
            return nil
        }

        let (nativeWidth, nativeHeight) = nativePanelResolution

        // The "Default for display" mode is the HiDPI mode where:
        // - The logical resolution is half the native panel resolution
        // - This provides true 2x scaling with the sharpest image
        let defaultLogicalWidth = nativeWidth / 2
        let defaultLogicalHeight = nativeHeight / 2

        // Find the HiDPI mode with these logical dimensions and highest refresh rate
        let matchingModes = modes.filter { mode in
            mode.isHiDPI && mode.width == defaultLogicalWidth && mode.height == defaultLogicalHeight
        }

        // Return the one with highest refresh rate
        if let defaultMode = matchingModes.max(by: { $0.refreshRate < $1.refreshRate }) {
            return defaultMode
        }

        // Fallback for non-Retina displays: use native resolution
        if let nativeMode = modes.first(where: { mode in
            !mode.isHiDPI && mode.width == nativeWidth && mode.height == nativeHeight
        }) {
            return nativeMode
        }

        return nil
    }

    /// Detects the native physical panel resolution of a display.
    ///
    /// This method identifies the true pixel dimensions of the display panel by analyzing
    /// available display modes. It looks for known Apple display resolutions and validates
    /// them by checking for matching HiDPI and 1:1 modes. For unknown displays, it uses
    /// heuristics to find the highest resolution with proper HiDPI support.
    ///
    /// - Parameter displayID: The Core Graphics display ID
    /// - Returns: A tuple containing the native width and height in pixels, or nil if detection fails
    private func getNativePanelResolution(for displayID: CGDirectDisplayID) -> (
        width: Int, height: Int
    )? {
        let options: CFDictionary =
            [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary

        guard let modesArray = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode]
        else {
            return nil
        }

        // Known native panel resolutions for Apple displays
        // The native resolution is where the panel physically has that many pixels
        let knownNativeResolutions: Set<String> = [
            "3024x1964",  // MacBook Pro 14" (M1 Pro/Max, M2 Pro/Max, M3, M4)
            "3456x2234",  // MacBook Pro 16" (M1 Pro/Max, M2 Pro/Max, M3, M4)
            "2560x1600",  // MacBook Air 13" (M1), MacBook Pro 13"
            "2560x1664",  // MacBook Air 13" (M2, M3)
            "2880x1864",  // MacBook Air 15" (M2, M3)
            "2880x1800",  // MacBook Pro 15" Retina (Intel)
            "5120x2880",  // Apple Studio Display, iMac 27" 5K
            "6016x3384",  // Pro Display XDR
            "4480x2520",  // iMac 24" 4.5K
            "4096x2304",  // iMac 21.5" 4K
        ]

        // Collect all matching native resolutions from this display's modes
        // We need to find the ACTUAL native resolution, not just any known resolution
        // The native resolution is the highest resolution that has both:
        // 1. A true 2x HiDPI mode (logical * 2 = pixel)
        // 2. A 1:1 mode at the same pixel dimensions
        var candidateResolutions: [(width: Int, height: Int)] = []

        for mode in modesArray {
            let key = "\(mode.pixelWidth)x\(mode.pixelHeight)"
            let isTrue2xHiDPI =
                mode.pixelWidth == mode.width * 2 && mode.pixelHeight == mode.height * 2

            if isTrue2xHiDPI && knownNativeResolutions.contains(key) {
                // Check if there's also a 1:1 mode at these pixel dimensions
                // (which indicates this is the actual panel resolution, not upscaled)
                let has1to1Mode = modesArray.contains { m in
                    m.pixelWidth == mode.pixelWidth && m.pixelHeight == mode.pixelHeight
                        && m.width == mode.pixelWidth && m.height == mode.pixelHeight
                }
                if has1to1Mode {
                    candidateResolutions.append((mode.pixelWidth, mode.pixelHeight))
                }
            }
        }

        // Return the highest resolution candidate (by pixel count)
        // This handles cases where multiple known resolutions match (e.g., scaled modes)
        if let best = candidateResolutions.max(by: {
            ($0.width * $0.height) < ($1.width * $1.height)
        }) {
            return best
        }

        // Fallback: For external/unknown displays, find the highest resolution mode
        // where there's both a 1:1 mode and a matching 2x HiDPI mode
        var fallbackResolutions: [(width: Int, height: Int)] = []

        for mode in modesArray {
            // Look for non-HiDPI mode (1:1 pixel mapping)
            if mode.pixelWidth == mode.width && mode.pixelHeight == mode.height {
                // Check if there's also an HiDPI mode at half this resolution
                let halfWidth = mode.width / 2
                let halfHeight = mode.height / 2
                let hasMatchingHiDPI = modesArray.contains { hiMode in
                    hiMode.width == halfWidth && hiMode.height == halfHeight
                        && hiMode.pixelWidth == mode.width && hiMode.pixelHeight == mode.height
                }
                if hasMatchingHiDPI {
                    fallbackResolutions.append((mode.width, mode.height))
                }
            }
        }

        // Return the highest resolution fallback
        if let best = fallbackResolutions.max(by: {
            ($0.width * $0.height) < ($1.width * $1.height)
        }) {
            return best
        }

        return nil
    }

    /// Retrieves the human-readable name for a display.
    ///
    /// Attempts to match the display ID with NSScreen objects to get the localized name.
    /// Falls back to "Built-in Display" or a generic name with the display ID.
    /// - Parameter displayID: The Core Graphics display ID
    /// - Returns: The display's name
    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        // Use NSScreen to get the display name
        for screen in NSScreen.screens {
            let screenNumber =
                screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID
            if screenNumber == displayID {
                if let name = screen.localizedName as String? {
                    return name
                }
            }
        }

        // Fallback to built-in check
        if CGDisplayIsBuiltin(displayID) != 0 {
            return "Built-in Display"
        }

        return "Display \(displayID)"
    }

    /// Retrieves all available display modes for a given display.
    ///
    /// Queries Core Graphics for all usable modes, filters duplicates, and sorts them
    /// by resolution (descending) and refresh rate (descending). HiDPI modes are prioritized
    /// when resolutions are equal.
    ///
    /// - Parameter displayID: The Core Graphics display ID
    /// - Returns: An array of sorted DisplayMode objects
    private func getDisplayModes(for displayID: CGDirectDisplayID) -> [DisplayMode] {
        let options: CFDictionary =
            [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary

        guard let modesArray = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode]
        else {
            return []
        }

        var modes: [DisplayMode] = []
        var seenModes = Set<String>()

        for (index, cgMode) in modesArray.enumerated() {
            let width = cgMode.width
            let height = cgMode.height
            let refreshRate = cgMode.refreshRate
            let isHiDPI = cgMode.pixelWidth > cgMode.width
            // Use a default bit depth since bitsPerPixel is deprecated
            let bitDepth = 32

            // Create a unique key to filter duplicates
            let key = "\(width)x\(height)@\(refreshRate)_\(isHiDPI)"
            guard !seenModes.contains(key) else { continue }
            seenModes.insert(key)

            // Only include usable modes
            guard cgMode.isUsableForDesktopGUI() else { continue }

            let mode = DisplayMode(
                modeNumber: Int32(index),
                width: width,
                height: height,
                refreshRate: refreshRate,
                isHiDPI: isHiDPI,
                bitDepth: bitDepth
            )
            modes.append(mode)
        }

        // Sort by resolution (descending) then refresh rate (descending)
        modes.sort { lhs, rhs in
            if lhs.width != rhs.width {
                return lhs.width > rhs.width
            }
            if lhs.height != rhs.height {
                return lhs.height > rhs.height
            }
            if lhs.refreshRate != rhs.refreshRate {
                return lhs.refreshRate > rhs.refreshRate
            }
            return lhs.isHiDPI && !rhs.isHiDPI
        }

        return modes
    }

    /// Gets the currently active display mode for a display.
    ///
    /// - Parameter displayID: The Core Graphics display ID
    /// - Returns: The current DisplayMode, or nil if it cannot be determined
    private func getCurrentMode(for displayID: CGDirectDisplayID) -> DisplayMode? {
        guard let cgMode = CGDisplayCopyDisplayMode(displayID) else {
            return nil
        }

        let isHiDPI = cgMode.pixelWidth > cgMode.width

        return DisplayMode(
            modeNumber: 0,
            width: cgMode.width,
            height: cgMode.height,
            refreshRate: cgMode.refreshRate,
            isHiDPI: isHiDPI,
            bitDepth: 32
        )
    }

    /// Changes a display to the specified mode.
    ///
    /// Initiates a display configuration transaction, finds the matching Core Graphics mode,
    /// applies the change, and commits it permanently. Automatically refreshes the display
    /// list after a short delay to reflect the changes.
    ///
    /// - Parameters:
    ///   - mode: The target DisplayMode to apply
    ///   - displayID: The Core Graphics display ID
    /// - Returns: `true` if the mode change was successful, `false` otherwise
    func setDisplayMode(_ mode: DisplayMode, for displayID: CGDirectDisplayID) -> Bool {
        let options: CFDictionary =
            [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary

        guard let modesArray = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode]
        else {
            return false
        }

        // Find the matching mode
        let targetMode = modesArray.first { cgMode in
            let isHiDPI = cgMode.pixelWidth > cgMode.width
            return cgMode.width == mode.width && cgMode.height == mode.height
                && cgMode.refreshRate == mode.refreshRate && isHiDPI == mode.isHiDPI
        }

        guard let cgMode = targetMode else {
            print("Could not find matching display mode")
            return false
        }

        var config: CGDisplayConfigRef?
        var result = CGBeginDisplayConfiguration(&config)
        guard result == .success, let config = config else {
            print("Failed to begin display configuration: \(result)")
            return false
        }

        result = CGConfigureDisplayWithDisplayMode(config, displayID, cgMode, nil)
        guard result == .success else {
            CGCancelDisplayConfiguration(config)
            print("Failed to configure display mode: \(result)")
            return false
        }

        result = CGCompleteDisplayConfiguration(config, .permanently)
        guard result == .success else {
            print("Failed to complete display configuration: \(result)")
            return false
        }

        // Refresh displays after change
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.refreshDisplays()
        }

        return true
    }

    /// Changes multiple displays to specified modes atomically.
    ///
    /// This method allows changing several displays in a single configuration transaction,
    /// ensuring all changes take effect simultaneously. This is useful for preset application
    /// where multiple displays need coordinated resolution changes.
    ///
    /// - Parameter configurations: An array of tuples containing display IDs and their target modes
    /// - Returns: `true` if all mode changes were successful, `false` if any failed
    func setMultipleDisplayModes(
        _ configurations: [(displayID: CGDirectDisplayID, mode: DisplayMode)]
    ) -> Bool {
        let options: CFDictionary =
            [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary

        var config: CGDisplayConfigRef?
        var result = CGBeginDisplayConfiguration(&config)
        guard result == .success, let config = config else {
            print("Failed to begin display configuration: \(result)")
            return false
        }

        for (displayID, mode) in configurations {
            guard
                let modesArray = CGDisplayCopyAllDisplayModes(displayID, options)
                    as? [CGDisplayMode]
            else {
                CGCancelDisplayConfiguration(config)
                return false
            }

            let targetMode = modesArray.first { cgMode in
                let isHiDPI = cgMode.pixelWidth > cgMode.width
                return cgMode.width == mode.width && cgMode.height == mode.height
                    && cgMode.refreshRate == mode.refreshRate && isHiDPI == mode.isHiDPI
            }

            guard let cgMode = targetMode else {
                CGCancelDisplayConfiguration(config)
                print("Could not find matching display mode for display \(displayID)")
                return false
            }

            result = CGConfigureDisplayWithDisplayMode(config, displayID, cgMode, nil)
            guard result == .success else {
                CGCancelDisplayConfiguration(config)
                print("Failed to configure display mode: \(result)")
                return false
            }
        }

        result = CGCompleteDisplayConfiguration(config, .permanently)
        guard result == .success else {
            print("Failed to complete display configuration: \(result)")
            return false
        }

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.refreshDisplays()
        }

        return true
    }

    /// Registers a callback to monitor display configuration changes.
    ///
    /// This method sets up system-level notifications for display events including
    /// mode changes, display additions, and removals. When triggered, it automatically
    /// refreshes the display list on the main actor.
    private func registerForDisplayChanges() {
        CGDisplayRegisterReconfigurationCallback(
            { displayID, flags, userInfo in
                if flags.contains(.setModeFlag) || flags.contains(.addFlag)
                    || flags.contains(.removeFlag)
                {
                    Task { @MainActor in
                        DisplayManager.shared.refreshDisplays()
                    }
                }
            }, nil)
    }

    nonisolated private func unregisterDisplayChanges() {
        CGDisplayRemoveReconfigurationCallback({ _, _, _ in }, nil)
    }
}
