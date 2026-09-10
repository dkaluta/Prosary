import Testing
@testable import Prosary

struct PrayerSearchCategoryTests {
  @Test func categoriesMergeLocalAndCommunityTags() {
    #expect(PrayerSearchCategory.available(in: [["Marian", " rosary "], ["marian", "Community"], []])
      == ["community", "marian", "other", "rosary"])
  }

  @Test func categorySelectionUsesTagsAndKeepsUntaggedEntriesDiscoverable() {
    #expect(PrayerSearchCategory.matches(["Marian", "Rosary"], selected: "marian"))
    #expect(!PrayerSearchCategory.matches(["Rosary"], selected: "marian"))
    #expect(PrayerSearchCategory.matches(["  "], selected: "other"))
    #expect(!PrayerSearchCategory.matches(["Rosary"], selected: "other"))
    #expect(PrayerSearchCategory.matches([], selected: nil))
    #expect(PrayerSearchCategory.matches(["Rosary"], selected: nil))
  }
}
