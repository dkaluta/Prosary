import XCTest

#if os(macOS)
/// These runs use an in-memory preset store and a per-process preferences suite. They never
/// reset the signed-in Mac's saved prayers, tags, preferences, or iCloud lists.
final class MacPrayerWindowUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor
  func testFreshLibraryAddsOneGalleryPrayerWithoutOpeningASession() throws {
    let app = launchApp(galleryDevotionIDs: [])
    let library = libraryWindow(in: app)
    XCTAssertTrue(library.buttons["Browse Prayer Gallery"].waitForExistence(timeout: 10))
    XCTAssertFalse(library.staticTexts["Angelus"].exists)
    XCTAssertFalse(library.staticTexts["Classic Rosary"].exists)
    library.buttons["Browse Prayer Gallery"].click()
    let categories = element("macGallery.categories", in: library)
    let unselectedAdd = library.buttons["macGallery.add"]
    XCTAssertTrue(categories.waitForExistence(timeout: 5))
    XCTAssertTrue(unselectedAdd.waitForExistence(timeout: 5))
    XCTAssertFalse(unselectedAdd.isEnabled, "The Gallery requires an explicit selection")
    XCTAssertTrue(library.frame.contains(categories.frame), "The category control must remain inside the window")
    XCTAssertTrue(library.frame.contains(unselectedAdd.frame), "The Gallery's action footer must remain inside the window")
    XCTAssertTrue(library.frame.contains(element("macLibrary.allPrayers", in: library).frame),
                  "Gallery document height must not push the split-view sidebar above the title bar")
    let galleryItem = element("macGallery.item.angelus", in: library)
    XCTAssertTrue(galleryItem.waitForExistence(timeout: 5))
    galleryItem.click()
    let add = library.buttons["macGallery.add.angelus"]
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    add.click()
    let showInLibrary = library.buttons["macGallery.show.angelus"]
    XCTAssertTrue(showInLibrary.waitForExistence(timeout: 5))
    XCTAssertFalse(add.exists)
    XCTAssertEqual(app.windows.count, 1, "Adding a Gallery entry does not start a prayer session")
    showInLibrary.click()
    let template = element("macLibrary.item.devotion:angelus", in: library)
    XCTAssertTrue(template.waitForExistence(timeout: 5))
    XCTAssertTrue(library.staticTexts["Angelus"].exists)
    XCTAssertFalse(library.staticTexts["Classic Rosary"].exists)

    // An already-added Gallery entry navigates to the same library object.
    element("macLibrary.gallery", in: library).click()
    XCTAssertTrue(galleryItem.waitForExistence(timeout: 5))
    galleryItem.click()
    XCTAssertFalse(add.exists)
    XCTAssertTrue(showInLibrary.waitForExistence(timeout: 5))
    showInLibrary.click()
    XCTAssertTrue(template.waitForExistence(timeout: 5))
    XCTAssertEqual(library.staticTexts.matching(identifier: "Angelus").count, 1)
    XCTAssertEqual(app.windows.count, 1)
  }

  @MainActor
  func testLibraryOpenReusesCopyWithoutRedundantWindowAction() throws {
    let app = launchApp()
    let library = libraryWindow(in: app)
    let angelus = library.staticTexts["Angelus"].firstMatch
    XCTAssertTrue(angelus.waitForExistence(timeout: 10))
    angelus.doubleClick()
    waitForWindowCount(2, in: app)
    let prayerWindows = app.windows.containing(.button, identifier: "prayerFlowNextButton")
    XCTAssertTrue(prayerWindows.firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(angelus.exists, "Opening a session must leave the library intact")

    // An ordinary Open on the same saved configuration activates its existing window.
    angelus.doubleClick()
    waitForWindowCount(2, in: app)

    // Context Open uses the same dedicated session; there is no duplicate window command.
    angelus.rightClick()
    let open = app.menuItems["Open"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    XCTAssertFalse(app.menuItems["Open in New Window"].exists)
    open.click()
    waitForWindowCount(2, in: app)
    XCTAssertEqual(prayerWindows.count, 1)
    let progress = prayerWindows.staticTexts["prayerProgressText"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    let original = progress.label
    app.typeKey(.return, modifierFlags: [])
    let changed = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in progress.label != original }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    XCTAssertTrue(angelus.exists)
    XCTAssertEqual(app.windows.count, 2)

  }

  @MainActor
  func testBasicPrayerActivationReusesSessionsWithoutRedundantWindowAction() throws {
    let app = launchApp(galleryDevotionIDs: [])
    let library = libraryWindow(in: app)
    let basicPrayers = element("macLibrary.basicPrayers", in: library)
    XCTAssertTrue(basicPrayers.waitForExistence(timeout: 10))
    basicPrayers.click()

    let signOfCross = library.buttons["basicPrayer-signOfCross"]
    XCTAssertTrue(signOfCross.waitForExistence(timeout: 5))
    signOfCross.click()
    waitForWindowCount(2, in: app)
    let sessions = app.windows.containing(.button, identifier: "presenterModeButton")
    let bodies = sessions.staticTexts.matching(identifier: "prayerBodyText")
    XCTAssertTrue(bodies.firstMatch.waitForExistence(timeout: 5))
    assertWindowCountRemains(2, in: app)
    XCTAssertEqual(sessions.count, 1, "One row click must open exactly one prayer session")
    let signOfCrossText = bodies.firstMatch.label
    XCTAssertFalse(signOfCrossText.isEmpty)

    // Scope every activation to the library and bring it forward through its harmless
    // sidebar selection; prayer windows can otherwise cover the directory's coordinates.
    basicPrayers.click()
    signOfCross.click()
    assertWindowCountRemains(2, in: app)
    basicPrayers.click()
    signOfCross.doubleClick()
    assertWindowCountRemains(2, in: app)
    XCTAssertEqual(bodies.firstMatch.label, signOfCrossText)

    basicPrayers.click()
    let ourFather = library.buttons["basicPrayer-ourFather"]
    XCTAssertTrue(ourFather.waitForExistence(timeout: 5))
    ourFather.click()
    waitForWindowCount(3, in: app)
    let distinctBodies = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      let text = bodies.allElementsBoundByIndex.map(\.label)
      return text.count == 2 && Set(text).count == 2 && text.contains(signOfCrossText)
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [distinctBodies], timeout: 5), .completed)
    assertWindowCountRemains(3, in: app)

    basicPrayers.click()
    signOfCross.rightClick()
    XCTAssertFalse(app.menuItems["Open in New Window"].exists)
    app.typeKey(.escape, modifierFlags: [])
    signOfCross.click()
    assertWindowCountRemains(3, in: app)
    XCTAssertEqual(sessions.count, 2, "Ordinary opening retains one window for each distinct prayer")
    XCTAssertTrue(signOfCross.exists, "Opening prayer windows must leave Basic Prayers available")

  }

  @MainActor
  func testDuplicateSavesNamedCopyAndTagFilterFindsIt() throws {
    let app = launchApp()
    let library = libraryWindow(in: app)
    let angelus = library.staticTexts["Angelus"].firstMatch
    XCTAssertTrue(angelus.waitForExistence(timeout: 10))
    angelus.rightClick()
    let duplicate = app.menuItems["Duplicate"]
    XCTAssertTrue(duplicate.waitForExistence(timeout: 5))
    duplicate.click()

    let sheet = library.sheets.firstMatch
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    let name = sheet.textFields.firstMatch
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.click()
    name.typeKey("a", modifierFlags: .command)
    name.typeText("Evening Angelus")
    let save = sheet.buttons["remindersEditorSaveButton"]
    let cancel = sheet.buttons["remindersEditorCancelButton"]
    XCTAssertTrue(save.exists)
    XCTAssertGreaterThan(save.frame.midX, cancel.frame.midX,
                         "The confirming action belongs to the right of Cancel")
    XCTAssertGreaterThan(save.frame.minY, name.frame.maxY,
                         "The Mac sheet keeps confirmation below the editable form")
    save.click()

    let copy = library.staticTexts["Evening Angelus"].firstMatch
    XCTAssertTrue(copy.waitForExistence(timeout: 5))
    XCTAssertTrue(angelus.exists, "Duplicating retains the original prayer")
    copy.rightClick()
    app.menuItems["Tags…"].click()
    let tokens = element("macLibrary.tagEditor.tokens", in: app)
    XCTAssertTrue(tokens.waitForExistence(timeout: 5))
    tokens.click()
    tokens.typeText("At Home,")
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(library.staticTexts["At Home"].firstMatch.waitForExistence(timeout: 5))

    copy.rightClick()
    app.menuItems["Tags…"].click()
    let red = app.checkBoxes["macLibrary.tagEditor.suggestion.red"]
    XCTAssertTrue(red.waitForExistence(timeout: 5))
    red.click()
    app.typeKey(.escape, modifierFlags: [])
    let redTag = element("macLibrary.tag.red", in: library)
    XCTAssertTrue(redTag.waitForExistence(timeout: 5))
    redTag.click()
    XCTAssertTrue(copy.waitForExistence(timeout: 5))
    XCTAssertFalse(angelus.exists, "A tag filter excludes the untagged original")

    redTag.rightClick()
    app.menuItems["Rename Tag…"].click()
    let alert = app.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    let tagName = alert.textFields.firstMatch
    tagName.click()
    tagName.typeKey("a", modifierFlags: .command)
    tagName.typeText("Evening")
    alert.buttons["Rename"].click()
    XCTAssertTrue(library.staticTexts["Evening"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(copy.exists, "Renaming a tag preserves its assignments and current filter")

    redTag.rightClick()
    app.menuItems["Tag Color"].click()
    app.menuItems["No Color"].click()
    XCTAssertTrue(copy.exists, "Removing a tag's color must preserve its name, filter and assignments")
    redTag.rightClick()
    app.menuItems["Delete Tag"].click()
    XCTAssertFalse(redTag.exists)
    XCTAssertTrue(copy.waitForExistence(timeout: 5))
    XCTAssertTrue(angelus.exists, "Deleting the selected tag returns to the library without deleting prayers")
    library.staticTexts["At Home"].firstMatch.click()
    XCTAssertTrue(copy.waitForExistence(timeout: 5))
    XCTAssertFalse(angelus.exists, "The independently named tag survives deletion of another tag")
  }

  @MainActor
  func testRosaryPrayerSettingsKeepsActionsBelowScrollableFields() throws {
    let app = launchApp(galleryDevotionIDs: ["rosary"])
    let library = libraryWindow(in: app)
    let rosary = element("macLibrary.item.devotion:rosary", in: library)
    XCTAssertTrue(rosary.waitForExistence(timeout: 10))
    rosary.rightClick()
    let settings = app.menuItems["Prayer Settings…"]
    XCTAssertTrue(settings.waitForExistence(timeout: 5))
    settings.click()

    let sheet = library.sheets.firstMatch
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    let fields = element("prayerEditorFields", in: sheet)
    let actions = element("prayerEditorActions", in: sheet)
    let save = sheet.buttons["favoriteEditorSaveButton"]
    let cancel = sheet.buttons["favoriteEditorCancelButton"]
    XCTAssertTrue(fields.waitForExistence(timeout: 5))
    XCTAssertTrue(actions.waitForExistence(timeout: 5))
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    XCTAssertTrue(cancel.exists)
    assertEditorFooter(fields: fields, actions: actions, save: save, cancel: cancel)
    let initialFooter = actions.frame

    // The long Rosary editor exposed the regression: its final controls painted beneath
    // the Save/Cancel inset. Reach its final control through the actual scroll viewport.
    let addReminder = fields.buttons["Add Reminder"]
    fields.scroll(byDeltaX: 0, deltaY: -fields.frame.height * 2)
    for _ in 0..<6 {
      if addReminder.exists && addReminder.isHittable && fields.frame.contains(addReminder.frame) { break }
      fields.scroll(byDeltaX: 0, deltaY: -fields.frame.height)
    }
    XCTAssertTrue(addReminder.waitForExistence(timeout: 5))
    XCTAssertTrue(addReminder.isHittable, "The final reminder control must remain reachable by scrolling")
    XCTAssertTrue(fields.frame.contains(addReminder.frame),
                  "The last field must be fully visible inside the scroll area, above the footer")
    assertEditorFooter(fields: fields, actions: actions, save: save, cancel: cancel)
    XCTAssertEqual(actions.frame.minY, initialFooter.minY, accuracy: 1,
                   "Scrolling settings must not move the confirmation row")
    XCTAssertEqual(actions.frame.height, initialFooter.height, accuracy: 1)
    XCTAssertLessThanOrEqual(addReminder.frame.maxY, actions.frame.minY,
                            "The final content control must not overlap the action row")

    // The stationary footer remains operable after scrolling; cancel avoids scheduling
    // reminders or persisting even this isolated test session's draft settings.
    cancel.click()
    let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
    XCTAssertEqual(app.windows.count, 1, "Editing settings must not open a prayer session")
  }

  @MainActor
  private func assertEditorFooter(
    fields: XCUIElement, actions: XCUIElement, save: XCUIElement, cancel: XCUIElement,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertGreaterThan(fields.frame.height, 0, file: file, line: line)
    XCTAssertGreaterThan(actions.frame.height, 0, file: file, line: line)
    XCTAssertGreaterThanOrEqual(actions.frame.minY, fields.frame.maxY - 1,
                               "Actions belong below the scroll viewport", file: file, line: line)
    XCTAssertTrue(actions.frame.contains(save.frame), "Save must stay inside the footer", file: file, line: line)
    XCTAssertTrue(actions.frame.contains(cancel.frame), "Cancel must stay inside the footer", file: file, line: line)
    XCTAssertGreaterThan(save.frame.midX, cancel.frame.midX,
                         "The confirming action belongs to the right of Cancel", file: file, line: line)
    XCTAssertTrue(save.isHittable, file: file, line: line)
    XCTAssertTrue(cancel.isHittable, file: file, line: line)
  }

  @MainActor
  func testPresenterModeForAngelusKeepsTheSamePrayer() throws {
    try checkPresenterMode(prayerName: "Angelus", devotionID: "angelus", usesKeyboardToEnter: false, isCounter: false)
  }

  @MainActor
  func testPresenterModeForRosaryKeepsTheSamePrayer() throws {
    try checkPresenterMode(prayerName: "The Holy Rosary", devotionID: "rosary", usesKeyboardToEnter: true, isCounter: false)
  }

  @MainActor
  func testPresenterModeForJesusPrayerKeepsTheSamePrayer() throws {
    try checkPresenterMode(prayerName: "Jesus Prayer", devotionID: "jesusPrayer", usesKeyboardToEnter: true, isCounter: true)
  }

  @MainActor
  private func checkPresenterMode(prayerName: String, devotionID: String, usesKeyboardToEnter: Bool, isCounter: Bool) throws {
    let app = launchApp(galleryDevotionIDs: [devotionID])
    let library = libraryWindow(in: app)
    let source = library.staticTexts[prayerName].firstMatch
    XCTAssertTrue(source.waitForExistence(timeout: 10))
    source.doubleClick()
    waitForWindowCount(2, in: app)

    let session = app.windows.containing(.button, identifier: "presenterModeButton").firstMatch
    let ordinaryBody = session.staticTexts["prayerBodyText"]
    XCTAssertTrue(ordinaryBody.waitForExistence(timeout: 5))
    let sourceBody = ordinaryBody.label
    XCTAssertFalse(sourceBody.isEmpty)
    let ordinaryProgress = session.staticTexts["prayerProgressText"]
    XCTAssertTrue(ordinaryProgress.exists)
    let sourceProgress = ordinaryProgress.label

    if usesKeyboardToEnter {
      app.typeKey("p", modifierFlags: [.command, .shift])
    } else {
      session.buttons["presenterModeButton"].click()
    }
    let presenterBody = session.staticTexts["presenterPrayerBodyText"]
    XCTAssertTrue(presenterBody.waitForExistence(timeout: 5))
    XCTAssertEqual(presenterBody.label, sourceBody,
                   "Presenter Mode must render the original prayer text without replacing its content")
    XCTAssertFalse(ordinaryBody.exists)

    let textSize = session.staticTexts["presenterTextSize"]
    XCTAssertTrue(textSize.waitForExistence(timeout: 5))
    let originalSize = try XCTUnwrap(textSize.value as? String)
    session.buttons["presenterLargerTextButton"].click()
    let larger = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value != %@", originalSize), object: textSize)
    XCTAssertEqual(XCTWaiter.wait(for: [larger], timeout: 5), .completed)
    session.buttons["presenterSmallerTextButton"].click()
    let restoredSize = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", originalSize), object: textSize)
    XCTAssertEqual(XCTWaiter.wait(for: [restoredSize], timeout: 5), .completed)
    XCTAssertEqual(presenterBody.label, sourceBody, "Changing presentation size must preserve the text")

    let presenterProgress = session.staticTexts["presenterProgressText"]
    XCTAssertEqual(presenterProgress.label, sourceProgress)
    let next = session.buttons["presenterNextButton"]
    XCTAssertTrue(next.exists)
    next.click()
    let advanced = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label != %@", sourceProgress), object: presenterProgress)
    XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 5), .completed)
    let back = session.buttons["presenterBackButton"]
    XCTAssertTrue(back.isEnabled)
    back.click()
    let returned = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", sourceProgress), object: presenterProgress)
    XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)

    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(ordinaryBody.waitForExistence(timeout: 5))
    XCTAssertFalse(presenterBody.exists)
    XCTAssertEqual(ordinaryBody.label, sourceBody)
    XCTAssertEqual(ordinaryProgress.label, sourceProgress)
    XCTAssertTrue(session.buttons[isCounter ? "centralActionButton" : "prayerFlowNextButton"].exists)
    XCTAssertTrue(source.exists, "Presenting a prayer must leave the source library item intact")

    // Closing and reopening the same object also uses the unchanged prayer and settings.
    app.typeKey("w", modifierFlags: .command)
    waitForWindowCount(1, in: app)
    source.doubleClick()
    waitForWindowCount(2, in: app)
    XCTAssertTrue(ordinaryBody.waitForExistence(timeout: 5))
    XCTAssertEqual(ordinaryBody.label, sourceBody)
    XCTAssertFalse(presenterBody.exists)
  }

  @MainActor
  private func launchApp(galleryDevotionIDs: [String] = ["angelus"]) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-useInMemoryStore",
      "-AppleLanguages", "(en)",
      "-defaultLanguageCode", "en",
      "-macLibraryDisplayStyle", "list",
      "-NSQuitAlwaysKeepsWindows", "NO",
    ]
    app.launch()
    if !galleryDevotionIDs.isEmpty {
      let library = libraryWindow(in: app)
      let gallery = element("macLibrary.gallery", in: library)
      XCTAssertTrue(gallery.waitForExistence(timeout: 10))
      gallery.click()
      for devotionID in galleryDevotionIDs {
        let galleryItem = element("macGallery.item.\(devotionID)", in: library)
        XCTAssertTrue(galleryItem.waitForExistence(timeout: 5))
        galleryItem.click()
        let add = library.buttons["macGallery.add.\(devotionID)"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Gallery should offer \(devotionID)")
        add.click()
        XCTAssertTrue(library.buttons["macGallery.show.\(devotionID)"].waitForExistence(timeout: 5))
      }
      element("macLibrary.allPrayers", in: library).click()
    }
    return app
  }

  @MainActor
  private func element(_ identifier: String, in scope: XCUIElement) -> XCUIElement {
    scope.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  @MainActor
  private func libraryWindow(in app: XCUIApplication) -> XCUIElement {
    app.windows.containing(.any, identifier: "macPrayerLibrary").firstMatch
  }

  @MainActor
  private func waitForWindowCount(_ count: Int, in app: XCUIApplication) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "count == %d", count), object: app.windows)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
  }

  @MainActor
  private func assertWindowCountRemains(
    _ count: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertEqual(app.windows.count, count, file: file, line: line)
    let unexpectedWindow = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "count != %d", count), object: app.windows)
    unexpectedWindow.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [unexpectedWindow], timeout: 1), .completed,
                   "Activation must not create another window after the first appears", file: file, line: line)
  }
}
#endif
