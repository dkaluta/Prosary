import XCTest

#if os(macOS)
/// These runs use an in-memory preset store and a per-process preferences suite. They never
/// reset the signed-in Mac's saved prayers, tags, preferences, or iCloud lists.
final class MacPrayerWindowUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor
  func testGalleryImageFileResetAndOnlineSearchStayInTheGallery() throws {
    let app = launchApp(galleryDevotionIDs: [])
    let library = libraryWindow(in: app)
    library.buttons["Browse Prayer Gallery"].click()
    let angelus = element("macGallery.item.angelus", in: library)
    XCTAssertTrue(angelus.waitForExistence(timeout: 5))
    angelus.rightClick()
    let choose = app.menuItems["Choose Image…"]
    XCTAssertTrue(choose.waitForExistence(timeout: 5), "The first right-click must offer image commands for a bundled prayer")
    XCTAssertFalse(app.menuItems["Use Default Image"].isEnabled)
    choose.click()
    let panel = app.sheets.firstMatch
    XCTAssertTrue(panel.waitForExistence(timeout: 5))

    let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("prosary-gallery-ui-\(UUID()).png")
    try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")).write(to: fixture)
    defer { try? FileManager.default.removeItem(at: fixture) }
    app.typeKey("g", modifierFlags: [.command, .shift])
    app.typeText(fixture.path)
    app.typeKey(.return, modifierFlags: [])
    let use = panel.buttons["Use Image"]
    XCTAssertTrue(use.waitForExistence(timeout: 5))
    use.click()
    XCTAssertTrue(panel.waitForNonExistence(timeout: 10))

    angelus.rightClick()
    let restore = app.menuItems["Use Default Image"]
    XCTAssertTrue(restore.waitForExistence(timeout: 5))
    XCTAssertTrue(restore.isEnabled, "The imported file must become the prayer's local Gallery image")
    restore.click()
    angelus.rightClick()
    XCTAssertTrue(app.menuItems["Use Default Image"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.menuItems["Use Default Image"].isEnabled)
    app.menuItems["Search Online…"].click()
    let query = app.textFields["macGallery.imageSearch.query"]
    XCTAssertTrue(query.waitForExistence(timeout: 5))
    XCTAssertEqual(query.value as? String, "Angelus")
    XCTAssertFalse(app.buttons["macGallery.imageSearch.use"].isEnabled)
    app.buttons["macGallery.imageSearch.cancel"].click()
    XCTAssertTrue(query.waitForNonExistence(timeout: 5))
    XCTAssertTrue(angelus.exists)
    XCTAssertTrue(library.buttons["macGallery.add"].exists,
      "Customizing artwork must not add a prayer to the library or change selection")
    XCTAssertEqual(app.windows.count, 1)
  }

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
  func testFinderTagRowStartsEmptyAndWorksInIconAndListViews() throws {
    for style in ["list", "icons"] {
      let app = launchApp(galleryDevotionIDs: ["angelus"], displayStyle: style)
      let library = libraryWindow(in: app)
      let title = library.staticTexts["Angelus"].firstMatch
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      let tagRows = library.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH %@", "macLibrary.tag."))
      XCTAssertEqual(tagRows.count, 0, "A fresh library must not seed color tags")

      title.rightClick()
      let menu = library.menus.firstMatch
      let clear = menu.radioButtons["macLibrary.tagSwatch.clear"]
      XCTAssertTrue(clear.waitForExistence(timeout: 5), "Both representations must use the native tag row")
      XCTAssertFalse(clear.isEnabled)
      XCTAssertEqual(menu.radioButtons.count, 1, "Unsaved color choices must never appear as tags")
      XCTAssertFalse(menu.menuItems["Tags"].exists, "The row must not be duplicated in another submenu")
      menu.buttons["macLibrary.editTags"].click()
      let tokens = element("macLibrary.tagEditor.tokens", in: library)
      XCTAssertTrue(tokens.waitForExistence(timeout: 5))
      app.typeKey(.escape, modifierFlags: [])
      XCTAssertEqual(tagRows.count, 0, "Opening Tags… creates nothing")

      title.rightClick()
      menu.buttons["macLibrary.editTags"].click()
      XCTAssertTrue(tokens.waitForExistence(timeout: 5))
      tokens.click()
      tokens.typeText("At Home,")
      app.typeKey(.return, modifierFlags: [])
      let savedTag = library.staticTexts["At Home"].firstMatch
      XCTAssertTrue(savedTag.waitForExistence(timeout: 5))
      title.rightClick()
      let tag = menu.radioButtons.matching(NSPredicate(format: "label == %@", "Remove “At Home”")).firstMatch
      XCTAssertTrue(tag.waitForExistence(timeout: 5), "An uncolored stored tag remains selectable")
      let tagID = tag.identifier
      XCTAssertEqual(menu.radioButtons.count, 2, "Only Clear and the actual stored tag are shown")
      XCTAssertTrue(clear.isEnabled)
      clear.click()
      XCTAssertTrue(savedTag.exists, "Clearing a prayer's tags keeps the person's named tag")
      title.rightClick()
      XCTAssertTrue(clear.waitForExistence(timeout: 5))
      let unassigned = menu.radioButtons[tagID]
      XCTAssertEqual(unassigned.label, "Add “At Home”")
      XCTAssertFalse(clear.isEnabled)
      unassigned.click()
      title.rightClick()
      XCTAssertTrue(menu.radioButtons[tagID].waitForExistence(timeout: 5))
      XCTAssertEqual(menu.radioButtons[tagID].label, "Remove “At Home”")
      app.typeKey(.escape, modifierFlags: [])
      XCTAssertEqual(app.windows.count, 1)
    }
  }

  @MainActor
  func testIconTitlesOpenTheClickedPrayersContextMenuRepeatedly() throws {
    let app = launchApp(galleryDevotionIDs: ["angelus", "rosary"], displayStyle: "icons")
    let library = libraryWindow(in: app)
    let angelus = library.staticTexts["Angelus"].firstMatch
    let rosary = library.staticTexts["The Holy Rosary"].firstMatch
    XCTAssertTrue(angelus.waitForExistence(timeout: 10))
    XCTAssertTrue(rosary.waitForExistence(timeout: 5))

    for (title, name) in [(rosary, "The Holy Rosary"), (angelus, "Angelus"), (rosary, "The Holy Rosary")] {
      title.rightClick()
      let settings = library.menuItems["Prayer Settings…"]
      XCTAssertTrue(settings.waitForExistence(timeout: 5), "A right click on the title must show the prayer menu")
      settings.click()
      let sheet = library.sheets.firstMatch
      XCTAssertTrue(sheet.waitForExistence(timeout: 5))
      XCTAssertEqual(sheet.textFields.firstMatch.value as? String, name,
        "The menu must target the clicked prayer, including after a previous menu closes")
      app.typeKey(.escape, modifierFlags: [])
      XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    XCUIElement.perform(withKeyModifiers: .control) { angelus.click() }
    XCTAssertTrue(library.menuItems["Prayer Settings…"].waitForExistence(timeout: 5))
    app.typeKey(.escape, modifierFlags: [])
    XCTAssertEqual(app.windows.count, 1, "Opening and canceling settings does not start a prayer")
  }

  @MainActor
  func testListContextMenuTargetsClickedAndFilteredPrayer() throws {
    let app = launchApp(galleryDevotionIDs: ["angelus", "rosary"])
    let library = libraryWindow(in: app)
    let angelus = library.staticTexts["Angelus"].firstMatch
    let rosary = library.staticTexts["The Holy Rosary"].firstMatch
    XCTAssertTrue(angelus.waitForExistence(timeout: 5))
    angelus.click()
    for (target, name) in [(rosary, "The Holy Rosary"), (angelus, "Angelus")] {
      target.rightClick()
      let settings = library.menuItems["Prayer Settings…"]
      XCTAssertTrue(settings.waitForExistence(timeout: 5))
      settings.click()
      let sheet = library.sheets.firstMatch
      XCTAssertTrue(sheet.waitForExistence(timeout: 5))
      XCTAssertEqual(sheet.textFields.firstMatch.value as? String, name)
      app.typeKey(.escape, modifierFlags: [])
      XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }
    let search = library.searchFields.firstMatch
    search.click()
    search.typeText("Rosary")
    XCTAssertTrue(rosary.waitForExistence(timeout: 5))
    XCTAssertFalse(angelus.exists)
    XCUIElement.perform(withKeyModifiers: .control) { rosary.click() }
    let settings = library.menuItems["Prayer Settings…"]
    XCTAssertTrue(settings.waitForExistence(timeout: 5))
    settings.click()
    let sheet = library.sheets.firstMatch
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    XCTAssertEqual(sheet.textFields.firstMatch.value as? String, "The Holy Rosary")
    app.typeKey(.escape, modifierFlags: [])
    XCTAssertEqual(app.windows.count, 1)
  }

  @MainActor
  func testDuplicateSavesNamedCopyAndTagFilterFindsIt() throws {
    let app = launchApp()
    let library = libraryWindow(in: app)
    let angelus = library.staticTexts["Angelus"].firstMatch
    XCTAssertTrue(angelus.waitForExistence(timeout: 10))
    angelus.rightClick()
    let duplicate = library.menuItems["Duplicate"]
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
    library.menus.firstMatch.buttons["macLibrary.editTags"].click()
    let tokens = element("macLibrary.tagEditor.tokens", in: app)
    XCTAssertTrue(tokens.waitForExistence(timeout: 5))
    tokens.click()
    tokens.typeText("At Home,Red,")
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(library.staticTexts["At Home"].firstMatch.waitForExistence(timeout: 5))

    let redLabel = library.staticTexts["Red"].firstMatch
    XCTAssertTrue(redLabel.waitForExistence(timeout: 5))
    let redTag = element(redLabel.identifier, in: library)
    redTag.rightClick()
    app.menuItems["Tag Color"].click()
    app.menuItems["Red"].click()
    copy.rightClick()
    let red = library.menus.firstMatch.radioButtons.matching(NSPredicate(format: "label == %@", "Remove “Red”")).firstMatch
    XCTAssertTrue(red.waitForExistence(timeout: 5))
    let redID = red.identifier
    red.click()
    copy.rightClick()
    let addRed = library.menus.firstMatch.radioButtons[redID]
    XCTAssertTrue(addRed.waitForExistence(timeout: 5))
    XCTAssertEqual(addRed.label, "Add “Red”")
    addRed.click()
    redTag.click()
    XCTAssertTrue(copy.waitForExistence(timeout: 5))
    XCTAssertFalse(angelus.exists, "A tag filter excludes the untagged original")

    redTag.rightClick()
    app.menuItems["Rename Tag…"].click()
    let alert = library.sheets.firstMatch
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
  private func launchApp(galleryDevotionIDs: [String] = ["angelus"], displayStyle: String = "list") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-useInMemoryStore",
      "-AppleLanguages", "(en)",
      "-defaultLanguageCode", "en",
      "-macLibraryDisplayStyle", displayStyle,
      "-NSQuitAlwaysKeepsWindows", "NO",
    ]
    app.launch()
    // macOS may restore the app with no windows after an earlier test closed its library.
    app.typeKey("n", modifierFlags: .command)
    XCTAssertTrue(libraryWindow(in: app).waitForExistence(timeout: 10))
    if !galleryDevotionIDs.isEmpty {
      let library = libraryWindow(in: app)
      let gallery = element("macLibrary.gallery", in: library)
      XCTAssertTrue(gallery.waitForExistence(timeout: 10))
      gallery.click()
      for devotionID in galleryDevotionIDs {
        let galleryItem = element("macGallery.item.\(devotionID)", in: library)
        // Native collections create accessibility items for visible cells only.
        let collection = element("macGallery.collection", in: library)
        for _ in 0..<8 {
          if galleryItem.exists { break }
          collection.scroll(byDeltaX: 0, deltaY: -300)
        }
        XCTAssertTrue(galleryItem.waitForExistence(timeout: 5))
        app.activate()
        galleryItem.click()
        let add = library.buttons["macGallery.add.\(devotionID)"]
        if !add.waitForExistence(timeout: 1) { galleryItem.click() }
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Gallery should offer \(devotionID)")
        add.click()
        XCTAssertTrue(library.buttons["macGallery.show.\(devotionID)"].waitForExistence(timeout: 5))
      }
      // The last added item exposes this native navigation action once it is installed.
      let showInLibrary = library.buttons["macGallery.show.\(galleryDevotionIDs.last!)"]
      XCTAssertTrue(showInLibrary.waitForExistence(timeout: 5))
      app.activate()
      showInLibrary.click()
    }
    return app
  }

  @MainActor
  private func element(_ identifier: String, in scope: XCUIElement) -> XCUIElement {
    scope.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  @MainActor
  private func libraryWindow(in app: XCUIApplication) -> XCUIElement {
    app.windows["main"]
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
