//
//  DisplayModeTests.swift
//  FujiTests
//
//  Created by Stephen Uffelman on 3/3/26.
//

import XCTest
@testable import Fuji

final class DisplayModeTests: XCTestCase {
    func testEqualityTreatsSmallRefreshRateDifferencesAsEqual() {
        let lhs = makeMode(width: 1920, height: 1080, refreshRate: 60.0, isHiDPI: false)
        let rhs = makeMode(width: 1920, height: 1080, refreshRate: 60.005, isHiDPI: false)

        XCTAssertEqual(lhs, rhs)
    }

    func testEqualityDiffersWhenHiDPIStatusDiffers() {
        let lhs = makeMode(width: 1920, height: 1080, refreshRate: 60.0, isHiDPI: false)
        let rhs = makeMode(width: 1920, height: 1080, refreshRate: 60.0, isHiDPI: true)

        XCTAssertNotEqual(lhs, rhs)
    }

    func testAspectRatioLabelForCommon16By9Mode() {
        let mode = makeMode(width: 1920, height: 1080, refreshRate: 60.0, isHiDPI: false)

        XCTAssertEqual(mode.aspectRatioLabel, "16:9")
    }

    func testAspectRatioLabelUsesApproximateMatchFor1366By768() {
        let mode = makeMode(width: 1366, height: 768, refreshRate: 60.0, isHiDPI: false)

        XCTAssertEqual(mode.aspectRatioLabel, "16:9")
    }

    private func makeMode(
        width: Int,
        height: Int,
        refreshRate: Double,
        isHiDPI: Bool
    ) -> DisplayMode {
        DisplayMode(
            modeNumber: 1,
            width: width,
            height: height,
            refreshRate: refreshRate,
            isHiDPI: isHiDPI,
            bitDepth: 32
        )
    }
}
