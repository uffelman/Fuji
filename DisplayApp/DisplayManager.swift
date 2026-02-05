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

struct DisplayMode: Identifiable, Hashable, Codable {
    let id: UUID
    let modeNumber: Int32
    let width: Int
    let height: Int
    let refreshRate: Double
    let isHiDPI: Bool
    let bitDepth: Int

    var displayString: String {
        let hiDPILabel = isHiDPI ? " (HiDPI)" : ""
        let refreshString = refreshRate > 0 ? " @ \(Int(refreshRate))Hz" : ""
        return "\(width) × \(height)\(refreshString)\(hiDPILabel)"
    }

    var shortDisplayString: String {
        return "\(width)×\(height)"
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
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(refreshRate)
        hasher.combine(isHiDPI)
    }

    static func == (lhs: DisplayMode, rhs: DisplayMode) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
            && lhs.refreshRate == rhs.refreshRate && lhs.isHiDPI == rhs.isHiDPI
    }
}

struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let isMain: Bool
    var modes: [DisplayMode]
    var currentMode: DisplayMode?
    var defaultMode: DisplayMode?

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
