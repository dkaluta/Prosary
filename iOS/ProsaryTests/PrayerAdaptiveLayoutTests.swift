import XCTest
@testable import Prosary

final class PrayerAdaptiveLayoutTests: XCTestCase {
  func testTwentyMysteriesFitAtTheFormerRegularWidthBreakpoint() {
    let layout = PrayerFlowLayout(available: CGSize(width: 860, height: 600), compactHeight: false,
      accessoryWidth: 220)
    XCTAssertTrue(layout.isWide)
    XCTAssertEqual(layout.wideImageSide, 204)
    XCTAssertLessThanOrEqual(layout.requiredWideWidth, layout.available.width)
    XCTAssertEqual(layout.minimumTextWidth, 320)
  }

  func testShortTwentyMysterySessionWaitsUntilEveryColumnFits() {
    let tooNarrow = PrayerFlowLayout(available: CGSize(width: 700, height: 250), compactHeight: true,
      accessoryWidth: 250)
    XCTAssertFalse(tooNarrow.isWide)
    let fits = PrayerFlowLayout(available: CGSize(width: 760, height: 250), compactHeight: true,
      accessoryWidth: 250)
    XCTAssertTrue(fits.isWide)
    XCTAssertFalse(fits.hasRoomForSingleMinorColumn)
    XCTAssertLessThanOrEqual(fits.requiredWideWidth, fits.available.width)
  }

  func testEverySupportedMysteryCountFitsWheneverWideLayoutIsSelected() {
    for groupCount in 1...4 {
      for height in [CGFloat(240), 300, 600] {
        for compact in [false, true] {
          for width in stride(from: CGFloat(320), through: 1400, by: 10) {
            let beads = CGFloat(groupCount * 34 + 40) + (height >= 300 ? 44 : 74)
            let layout = PrayerFlowLayout(available: CGSize(width: width, height: height),
              compactHeight: compact, accessoryWidth: beads)
            if layout.isWide {
              XCTAssertLessThanOrEqual(layout.requiredWideWidth, min(width, 1100))
              XCTAssertGreaterThanOrEqual(layout.wideImageSide, compact ? 120 : 160)
            }
          }
        }
      }
    }
  }

  func testPrayerWithoutBeadsDoesNotReserveAnEmptyAccessoryColumn() {
    let layout = PrayerFlowLayout(available: CGSize(width: 860, height: 600), compactHeight: false,
      accessoryWidth: nil)
    XCTAssertTrue(layout.isWide)
    XCTAssertEqual(layout.wideImageSide, 320)
    XCTAssertEqual(layout.columnOverhead, 92)
  }

  func testVeryShortViewportKeepsArtworkInsideTheScrollingLayout() {
    let layout = PrayerFlowLayout(available: CGSize(width: 900, height: 100), compactHeight: true,
      accessoryWidth: 250)
    XCTAssertFalse(layout.isWide)
  }
}

final class PrayerReservedRegionLayoutTests: XCTestCase {
  private let viewport = CGRect(x: 0, y: 0, width: 800, height: 600)

  func testMissingAndNonIntersectingCamerasKeepTheFullViewport() {
    XCTAssertEqual(PrayerReservedRegionLayout.unobscuredFrame(in: viewport, avoiding: []), viewport)
    XCTAssertEqual(PrayerReservedRegionLayout.unobscuredFrame(in: viewport,
      avoiding: [CGRect(x: 800, y: 0, width: 40, height: 40)]), viewport)
  }

  func testActiveCornerCameraLeavesTheLargestUnobscuredReadingArea() {
    let camera = CGRect(x: 740, y: 0, width: 60, height: 80)
    let result = PrayerReservedRegionLayout.unobscuredFrame(in: viewport, avoiding: [camera])
    XCTAssertEqual(result, CGRect(x: 0, y: 0, width: 740, height: 600))
    XCTAssertFalse(PrayerReservedRegionLayout.intersects(camera, bounds: result))
  }

  func testCameraInTheTopCenterMovesContentBelowItsIncludedMargins() {
    let camera = CGRect(x: 350, y: 0, width: 100, height: 70)
    let result = PrayerReservedRegionLayout.unobscuredFrame(in: viewport, avoiding: [camera])
    XCTAssertEqual(result, CGRect(x: 0, y: 70, width: 800, height: 530))
    XCTAssertFalse(PrayerReservedRegionLayout.intersects(camera, bounds: result))
  }

  func testMultipleOcclusionsAndOffscreenMarginsStayOutsideTheReader() {
    let cameras = [CGRect(x: -20, y: -20, width: 80, height: 100),
      CGRect(x: 740, y: 500, width: 80, height: 120)]
    let result = PrayerReservedRegionLayout.unobscuredFrame(in: viewport, avoiding: cameras)
    XCTAssertEqual(result, CGRect(x: 60, y: 0, width: 680, height: 600))
    XCTAssertTrue(viewport.contains(result))
    for camera in cameras {
      XCTAssertFalse(PrayerReservedRegionLayout.intersects(camera, bounds: result))
    }
  }

  func testPhysicalCameraPlacementDoesNotDependOnThePrayerWritingDirection() {
    let leftCamera = CGRect(x: 0, y: 0, width: 60, height: 80)
    let rightCamera = CGRect(x: 740, y: 0, width: 60, height: 80)
    XCTAssertEqual(PrayerReservedRegionLayout.unobscuredFrame(in: viewport, avoiding: [leftCamera]),
      CGRect(x: 60, y: 0, width: 740, height: 600))
    XCTAssertEqual(PrayerReservedRegionLayout.unobscuredFrame(in: viewport, avoiding: [rightCamera]),
      CGRect(x: 0, y: 0, width: 740, height: 600))
  }

  func testZeroSizeAndCompletelyOccludedViewportsStayBounded() {
    XCTAssertEqual(PrayerReservedRegionLayout.unobscuredFrame(in: .zero, avoiding: [viewport]), .zero)
    XCTAssertEqual(PrayerReservedRegionLayout.unobscuredFrame(in: viewport, avoiding: [viewport]), .zero)
  }

  func testArrangementPaneOnlyAvoidsThePartOfACameraInsideItsBounds() {
    let pane = CGRect(x: 420, y: 0, width: 380, height: 600)
    let camera = CGRect(x: 400, y: -10, width: 70, height: 90)
    let result = PrayerReservedRegionLayout.unobscuredFrame(in: pane, avoiding: [camera])
    XCTAssertEqual(result, CGRect(x: 470, y: 0, width: 330, height: 600))
    XCTAssertTrue(pane.contains(result))
    XCTAssertFalse(PrayerReservedRegionLayout.intersects(camera, bounds: result))
  }

  func testRotatedShortPaneKeepsItsCameraAndIncludedMarginsOutsideContent() {
    let pane = CGRect(x: 0, y: 320, width: 800, height: 280)
    let camera = CGRect(x: 350, y: 300, width: 100, height: 70)
    let result = PrayerReservedRegionLayout.unobscuredFrame(in: pane, avoiding: [camera])
    XCTAssertEqual(result, CGRect(x: 0, y: 370, width: 800, height: 230))
    XCTAssertTrue(pane.contains(result))
    XCTAssertFalse(PrayerReservedRegionLayout.intersects(camera, bounds: result))
  }
}

final class PrayerReadingLocationTests: XCTestCase {
  func testReadingPositionFollowsPrayerTextWhenArtworkMovesOutOfTheScroller() {
    var location = PrayerReadingLocation()
    location.record(offset: 600, textTop: 300, textHeight: 1200)
    XCTAssertEqual(location.offset(textTop: 16, textHeight: 800, maximumOffset: 700), 216)
    XCTAssertEqual(location.offset(textTop: 300, textHeight: 1200, maximumOffset: 1300), 600)
  }

  func testResizingAtTheStartKeepsTheArtworkAndHeadingVisible() {
    var location = PrayerReadingLocation()
    location.record(offset: 0, textTop: 300, textHeight: 1200)
    XCTAssertEqual(location.offset(textTop: 16, textHeight: 800, maximumOffset: 700), 0)
  }

  func testTheLastPartOfThePrayerClampsToTheNewScrollableExtent() {
    var location = PrayerReadingLocation()
    location.record(offset: 1200, textTop: 200, textHeight: 1200)
    XCTAssertEqual(location.offset(textTop: 16, textHeight: 300, maximumOffset: 100), 100)
    XCTAssertEqual(location.offset(textTop: 16, textHeight: 300, maximumOffset: -20), 0)
  }

  @MainActor
  func testReappearingKeepsThePositionAndANewStepStartsAtTheTop() {
    let position = PrayerReadingPosition()
    position.start(step: 4)
    position.location.record(offset: 600, textTop: 300, textHeight: 1200)
    position.start(step: 4)
    XCTAssertEqual(position.location.fraction, 0.25)
    position.start(step: 5)
    XCTAssertEqual(position.location, PrayerReadingLocation())
  }
}
