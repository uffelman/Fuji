//
//  DisplayResolutionGroupingTests.swift
//  FujiTests
//
//  Created by Stephen Uffelman on 3/3/26.
//

import XCTest
@testable import Fuji

final class DisplayResolutionGroupingTests: XCTestCase {
    func testUniqueResolutionGroupsGroupsContiguousModesByDimensions() {
        let modes = [
            makeMode(width: 1920, height: 1080, refreshRate: 120),
            makeMode(width: 1920, height: 1080, refreshRate: 60),
            makeMode(width: 1680, height: 1050, refreshRate: 60),
            makeMode(width: 1280, height: 720, refreshRate: 60),
            makeMode(width: 1280, height: 720, refreshRate: 50),
        ]

        let display = Display(
            id: 1,
            name: "Built-in Display",
            isBuiltIn: true,
            isMain: true,
            modes: modes,
            currentMode: modes[1],
            defaultMode: modes[1]
        )

        let groups = display.uniqueResolutionGroups()

        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups.map(\.count), [2, 1, 2])
        XCTAssertEqual(groups.map { "\($0[0].width)x\($0[0].height)" }, ["1920x1080", "1680x1050", "1280x720"])
    }

    private func makeMode(width: Int, height: Int, refreshRate: Double) -> DisplayMode {
        DisplayMode(
            modeNumber: 1,
            width: width,
            height: height,
            refreshRate: refreshRate,
            isHiDPI: false,
            bitDepth: 32
        )
    }
}
