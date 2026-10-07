using System.Text.Json;
using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class BundledReadingsTests
{
    private static ReadingsTextStore Store => ReadingsTextStore.Default;

    [Theory]
    [InlineData("1 Corinthians 8:1b–7; 8:11–13", 8, new[] { 1, 2, 3, 4, 5, 6, 7, 11, 12, 13 })]
    [InlineData("Psalm 139:1–3; 139:13–14ab; 139:23–24", 138, new[] { 1, 2, 3, 4, 13, 14, 23, 24 })]
    public void SeptemberTenthPartialReferencesOpenWholeVersesWithNotice(string citation, int chapter, int[] verseNumbers)
    {
        var edition = Store.ResolveEdition("douay-rheims-1899", "en");
        Assert.NotNull(edition);
        var passage = Store.LoadPassage("daily", citation, edition.Id);
        Assert.NotNull(passage);
        Assert.True(passage.IncludesWholeVerses);
        Assert.Equal(verseNumbers, passage.Verses.Select(verse => verse.Verse));
        Assert.All(passage.Verses, verse => Assert.Equal(chapter, verse.Chapter));
        Assert.All(passage.Verses, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));

        var row = new ReadingPassageViewModel(Store, edition, "daily",
            new ReadingCitation("reading", "Reading", citation), "en", "date", "edition");
        row.IsExpanded = true;
        Assert.True(row.HasPassage);
        Assert.True(row.IncludesWholeVerses);
        Assert.Equal(citation, row.Citation);
        Assert.Contains(passage.Verses.First().Text, row.PassageText);
        Assert.False(Store.LoadPassage("daily", "Luke 6:27–38", edition.Id)!.IncludesWholeVerses);
    }

    [Fact]
    public void SeptemberThirteenthReadingsUseTheSelectedEditionsNumbering()
    {
        var cases = new (string Citation, IEnumerable<string> Expected)[]
        {
            ("Sirach 27:30; 28:1–7", new[] { "27:33" }.Concat(Enumerable.Range(1, 9).Select(v => $"28:{v}"))),
            ("Psalm 103:1–2; 103:3–4; 103:9–10; 103:11–12", new[] { 1, 2, 3, 4, 9, 10, 11, 12 }.Select(v => $"102:{v}")),
            ("Romans 14:7–9", Enumerable.Range(7, 3).Select(v => $"14:{v}")),
            ("Matthew 18:21–35", Enumerable.Range(21, 15).Select(v => $"18:{v}"))
        };
        foreach (var (citation, expected) in cases)
        {
            var passage = Store.LoadPassage("daily", citation, "douay-rheims-1899");
            Assert.NotNull(passage);
            Assert.Equal(expected, passage.Verses.Select(v => $"{v.Chapter}:{v.Verse}"));
            Assert.All(passage.Verses, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));
        }
        var psalmEditions = new Dictionary<string, int>
        {
            ["douay-rheims-1899"] = 102, ["synodal-1876"] = 102,
            ["masoretic-delitzsch"] = 103, ["ang-dating-biblia-1905"] = 103,
            ["crampon-1923"] = 103, ["kulish-1905"] = 103,
            ["jesuit-arabic-1897"] = 102, ["martini"] = 102, ["peshitta-1905"] = 103
        };
        foreach (var (editionId, chapter) in psalmEditions)
        {
            var psalm = Store.LoadPassage("daily", cases[1].Citation, editionId);
            Assert.NotNull(psalm);
            Assert.Equal(new[] { 1, 2, 3, 4, 9, 10, 11, 12 }, psalm.Verses.Select(v => v.Verse));
            Assert.All(psalm.Verses, verse => Assert.Equal(chapter, verse.Chapter));
            Assert.True(psalm.IncludesWholeVerses);
        }
        var french = Store.LoadPassage("daily", cases[0].Citation, "crampon-1923");
        Assert.NotNull(french);
        Assert.Equal(new[] { "27:30" }.Concat(Enumerable.Range(1, 7).Select(v => $"28:{v}")),
            french.Verses.Select(v => $"{v.Chapter}:{v.Verse}"));
        Assert.All(french.Verses, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));
        var hebrew = Assert.IsType<ScripturePassage>(Store.LoadPassage("daily", cases[0].Citation, "masoretic-delitzsch"));
        Assert.Equal(new[] { "27:30" }.Concat(Enumerable.Range(1, 7).Select(v => $"28:{v}")),
            hebrew.Verses.Select(v => $"{v.Chapter}:{v.Verse}"));
        Assert.Equal("SIR", hebrew.Source!.Book);
        Assert.Equal("דברי שמעון בן־סירא", hebrew.Source.Name);
        Assert.Contains("ההדיר ותרגם אברהם כהנא", hebrew.Source.Attribution);
        Assert.False(hebrew.Source.IsComplete);
    }

    [Fact]
    public void EveryBundledHebrewSourcePassageResolvesItsCreditAndOrderedDisplay()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(
            Path.Combine(AppContext.BaseDirectory, "Data", "readings-texts.json")));
        var data = document.RootElement;
        var sources = data.GetProperty("passageSources").EnumerateObject()
            .Where(source => source.Value.TryGetProperty("masoretic-delitzsch", out _)).ToList();
        Assert.Equal(19, sources.Count);
        // Wisdom 7 is reviewed for Maronite use, but also occurs in an unreviewed Roman 1962 context.
        Assert.Null(Store.LoadPassage("daily", "Wisdom 7:7–14", "masoretic-delitzsch"));
        var edition = Assert.IsType<ScriptureEdition>(Store.ResolveEdition("masoretic-delitzsch", "he"));
        var wholeKeys = data.GetProperty("wholeVersePassages").EnumerateArray().Select(value => value.GetString()).ToHashSet();
        foreach (var entry in sources)
        {
            var parts = entry.Name.Split('|', 2);
            var source = entry.Value.GetProperty(edition.Id);
            var expectedRows = data.GetProperty("passages").GetProperty(entry.Name).GetProperty(edition.Id).EnumerateArray().ToList();
            var passage = Assert.IsType<ScripturePassage>(Store.LoadPassage(parts[0], parts[1], edition.Id));
            Assert.Equal(source.GetProperty("book").GetString(), passage.Source!.Book);
            Assert.Equal(expectedRows.Select(row => (row.GetProperty("chapter").GetInt32(), row.GetProperty("verse").GetInt32(),
                    End: row.TryGetProperty("endVerse", out var end) ? (int?)end.GetInt32() : null, row.GetProperty("text").GetString())),
                passage.Verses.Select(row => (row.Chapter, row.Verse, row.EndVerse, row.Text)));
            var displays = passage.SourceDisplays(edition);
            Assert.NotNull(displays);
            var units = displays.SelectMany(display => display.Units).ToList();
            var blocks = source.GetProperty("contentBlocks").EnumerateArray().ToList();
            Assert.Equal(blocks.Select(block => block.GetProperty("id").GetString()), units.Select(unit => unit.Id));
            Assert.Equal(passage.Verses, units.Where(unit => unit.Primary is not null).Select(unit => unit.Primary!));

            var view = new ReadingPassageViewModel(Store, edition, parts[0],
                new ReadingCitation("reading", "Reading", parts[1]), "he", entry.Name, edition.Id);
            view.IsExpanded = true;
            Assert.True(view.HasPassage);
            Assert.True(view.HasSourceName);
            Assert.Equal(source.GetProperty("name").GetString(), view.SourceName);
            Assert.Equal(source.GetProperty("attribution").GetString(), view.Attribution);
            Assert.Equal(new Uri(source.GetProperty("sourceURL").GetString()!), view.SourceUri);
            Assert.Equal(!source.GetProperty("isComplete").GetBoolean(), view.IsPartial);
            Assert.Equal(wholeKeys.Contains(entry.Name), view.IncludesWholeVerses);
            var rendered = view.Chapters.SelectMany(chapter => chapter.Verses!).ToList();
            Assert.Equal(units.Select(unit => (unit.Id, unit.Kind, unit.PrintedLabel)),
                rendered.Select(row => (row.Id, row.Kind, row.PrintedLabel)));
            Assert.Equal(units.Select(unit => unit.Primary?.Text ?? unit.Text), rendered.Select(row => row.Text));
            var expectedNotes = expectedRows.SelectMany(NoteIds)
                .Concat(blocks.Where(block => block.GetProperty("kind").GetString() != "verse").SelectMany(NoteIds)).Order();
            Assert.Equal(expectedNotes, rendered.SelectMany(row => row.SourceNotes ?? []).Select(note => note.Id).Order());
        }

        static IEnumerable<string> NoteIds(JsonElement row) => row.TryGetProperty("sourceNotes", out var notes)
            ? notes.EnumerateArray().Select(note => note.GetProperty("id").GetString()!).ToList() : [];
    }

    [Fact]
    public void HebrewSirachDailyPassageKeepsItsActualSourceNoteAndPartialNotice()
    {
        const string citation = "Sirach 51:13–17";
        var edition = Assert.IsType<ScriptureEdition>(Store.ResolveEdition("masoretic-delitzsch", "he"));
        var passage = Assert.IsType<ScripturePassage>(Store.LoadPassage("daily", citation, edition.Id));
        Assert.Equal(Enumerable.Range(9, 4), passage.Verses.Select(verse => verse.Verse));
        Assert.All(passage.Verses, verse => Assert.Equal(51, verse.Chapter));
        var note = Assert.Single(passage.Verses.SelectMany(verse => verse.SourceNotes ?? []));
        Assert.Equal("sir-51-11-alef-vowel", note.Id);
        Assert.Equal("וְאזְכֶּרְךָ", note.Anchor);
        Assert.Equal(2, note.LetterIndex);
        Assert.Equal("vowel", note.Mark);
        Assert.Equal(new[] { 529 }, note.SourcePages);
        var view = new ReadingPassageViewModel(Store, edition, "daily",
            new ReadingCitation("reading", "Sirach", citation), "he", "date", "edition");
        view.IsExpanded = true;
        Assert.True(view.IsPartial);
        Assert.Equal(note.Id, Assert.Single(view.Chapters.SelectMany(chapter => chapter.Verses!)
            .SelectMany(row => row.SourceNotes ?? [])).Id);
        Assert.DoesNotContain(note.Id, view.PassageText);
    }

    [Fact]
    public void HebrewDanielAppointmentUsesTheCreditedAzariahSourceAndCombinedUnit()
    {
        const string citation = "Daniel 3:25, 34–45";
        var edition = Assert.IsType<ScriptureEdition>(Store.ResolveEdition("masoretic-delitzsch", "he"));
        var passage = Assert.IsType<ScripturePassage>(Store.LoadPassage("daily", citation, edition.Id));
        Assert.Equal("S3Y", passage.Source!.Book);
        Assert.Equal("תפלת עזריה ושירת שלשת הנערים בכבשן", passage.Source.Name);
        Assert.Contains("תרגום דב היליר", passage.Source.Attribution);
        Assert.Equal(new[] { 4 }.Concat(Enumerable.Range(13, 10)).Append(24), passage.Verses.Select(row => row.Verse));
        Assert.All(passage.Verses, row => Assert.Equal(1, row.Chapter));
        Assert.Equal(23, Assert.Single(passage.Verses.Where(row => row.Verse == 22)).EndVerse);
        var view = new ReadingPassageViewModel(Store, edition, "daily",
            new ReadingCitation("reading", "Daniel", citation), "he", "date", "edition");
        view.IsExpanded = true;
        Assert.Equal(passage.Source.Name, view.SourceName);
        Assert.Equal(passage.Source.Attribution, view.Attribution);
        Assert.True(view.IncludesWholeVerses);
        Assert.False(view.IsPartial);
        Assert.Equal(1, Assert.Single(view.Chapters).Number);
    }

    [Fact]
    public void SeptemberSixteenthPsalmOpensWithTheSelectedEditionsNumbering()
    {
        const string citation = "Psalm 33:2–3; 33:4–5; 33:12; 33:22";
        foreach (var (editionId, chapter) in new[]
        {
            ("douay-rheims-1899", 32), ("brenton-lxx", 32), ("masoretic-delitzsch", 33),
        })
        {
            var passage = Store.LoadPassage("daily", citation, editionId);
            Assert.NotNull(passage);
            Assert.Equal(new[] { 2, 3, 4, 5, 12, 22 }, passage.Verses.Select(verse => verse.Verse));
            Assert.All(passage.Verses, verse =>
            {
                Assert.Equal(chapter, verse.Chapter);
                Assert.False(string.IsNullOrWhiteSpace(verse.Text));
            });
        }
        Assert.StartsWith("Ἐξομολογεῖσθε τῷ Κυρίῳ", Store.LoadPassage("daily", citation, "brenton-lxx")!.Verses[0].Text);
        Assert.Equal(new[] { "ang-dating-biblia-1905", "brenton-lxx", "crampon-1923", "douay-rheims-1899",
            "jesuit-arabic-1897", "kulish-1905", "martini", "masoretic-delitzsch", "peshitta-1905", "synodal-1876" },
            Store.AvailableEditions("daily", citation).Select(edition => edition.Id).Order());
    }

    [Theory]
    [InlineData(3)]
    [InlineData(5)]
    public void CorinthiansAppointmentsKeepTheClosingBlessingAcrossEditionNumbering(int start)
    {
        var citation = $"2 Corinthians 13:{start}–13";
        var tagalog = Store.LoadPassage("daily", citation, "ang-dating-biblia-1905");
        Assert.NotNull(tagalog);
        Assert.Equal(Enumerable.Range(start, 15 - start), tagalog.Verses.Select(verse => verse.Verse));
        Assert.All(tagalog.Verses, verse =>
        {
            Assert.Equal(13, verse.Chapter);
            Assert.False(string.IsNullOrWhiteSpace(verse.Text));
        });
        Assert.Contains("Espiritu Santo", tagalog.Verses.Last().Text);
        var douay = Store.LoadPassage("daily", citation, "douay-rheims-1899");
        Assert.NotNull(douay);
        Assert.Equal(Enumerable.Range(start, 14 - start), douay.Verses.Select(verse => verse.Verse));
        Assert.All(douay.Verses, verse => Assert.Equal(13, verse.Chapter));
        Assert.Contains("Holy Ghost", douay.Verses.Last().Text);
    }

    [Theory]
    [InlineData("Mark 3:20–30", "ang-dating-biblia-1905", 3, 19, 30)]
    [InlineData("Mark 3:20–30", "peshitta-1905", 3, 19, 30)]
    [InlineData("Luke 7:11–18", "douay-rheims-1899", 7, 11, 19)]
    public void BoundaryAppointmentsRetainLeadingAndTrailingClausesWithWholeVerseNotice(
        string citation, string editionId, int chapter, int first, int last)
    {
        var passage = Store.LoadPassage("daily", citation, editionId);
        Assert.NotNull(passage);
        Assert.True(passage.IncludesWholeVerses);
        Assert.Equal(Enumerable.Range(first, last - first + 1), passage.Verses.Select(verse => verse.Verse));
        Assert.All(passage.Verses, verse =>
        {
            Assert.Equal(chapter, verse.Chapter);
            Assert.False(string.IsNullOrWhiteSpace(verse.Text));
        });
    }

    [Fact]
    public void BundledCatalogHasTenEditionsAndPreservesTheSevenFullBibleEditions()
    {
        Assert.Equal(10, Store.Editions.Count);
        Assert.Equal(new[] { "ar", "arc", "el", "en", "fr", "he", "it", "ru", "tl", "uk" },
            Store.Editions.Select(edition => edition.LanguageCode).Order());
        foreach (var edition in Store.Editions)
        {
            Assert.NotNull(edition.SourceUri);
            Assert.False(string.IsNullOrWhiteSpace(edition.Attribution));
            // Arabic currently contains only the passages reviewed against the old print.
            if (edition.LanguageCode is "ar" or "arc" or "el") continue;
            var passage = Store.Passage("daily", "Luke 6:27–38", edition.Id);
            Assert.Equal(Enumerable.Range(27, 12), passage.Select(verse => verse.Verse));
            Assert.All(passage, verse => Assert.Equal(6, verse.Chapter));
            Assert.All(passage, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));
        }
    }

    [Fact]
    public void GreekSeptuagintIsSelectableAndNeverBorrowsANewTestament()
    {
        var edition = Store.ResolveEdition("brenton-lxx", "he");
        Assert.NotNull(edition);
        Assert.Equal("el", edition.LanguageCode);
        Assert.Contains("Old Testament only", edition.Attribution);
        Assert.Empty(Store.Passage("daily", "Luke 6:27–38", edition.Id));
        var psalm = Store.LoadPassage("daily", "Psalm 103:1–2; 103:3–4; 103:9–10; 103:11–12", edition.Id);
        Assert.NotNull(psalm);
        Assert.All(psalm.Verses, verse => Assert.Equal(102, verse.Chapter));
        Assert.Equal(new[] { 1, 2, 3, 4, 9, 10, 11, 12 }, psalm.Verses.Select(verse => verse.Verse));
    }

    [Fact]
    public void BundledPeshittaCarriesBothScriptsForTheSameOrderedVerses()
    {
        var edition = Store.ResolveEdition("peshitta-1905", "en");
        Assert.NotNull(edition);
        Assert.True(edition.HasAramaicScripts);
        Assert.Equal("arc", edition.LanguageCode);
        var passage = Store.LoadPassage("daily", "Luke 6:27–38", edition.Id);
        Assert.NotNull(passage);
        Assert.Equal(Enumerable.Range(27, 12), passage.Verses.Select(verse => verse.Verse));
        Assert.All(passage.Verses, verse =>
        {
            Assert.Equal(6, verse.Chapter);
            Assert.Equal(PrayerTypography.Script.Hebrew, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Hebr")));
            Assert.Equal(PrayerTypography.Script.Syriac, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Syrc")));
            Assert.Equal(verse.TransliteratedText, verse.DisplayedText(edition, "Syrc"));
        });
    }

    [Fact]
    public void ExpandedPeshittaOldTestamentKeepsSourcePairAndExplicitGaps()
    {
        var edition = Store.ResolveEdition("peshitta-1905", "en");
        Assert.NotNull(edition);
        var genesis = Store.LoadPassage("daily", "Genesis 1:1–13", edition.Id);
        Assert.NotNull(genesis);
        Assert.Equal(Enumerable.Range(1, 13), genesis.Verses.Select(verse => verse.Verse));
        Assert.StartsWith("ܒܪܺܝܫܺܝܬ ܒܪܳܐ", genesis.Verses.First().TransliteratedText);
        Assert.Contains("Old Testament - publication of the Syriac Orthodox Patriarchate 2020", edition.Attribution);
        Assert.All(genesis.Verses, verse =>
        {
            Assert.Equal(1, verse.Chapter);
            Assert.Equal(PrayerTypography.Script.Hebrew, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Hebr")));
            Assert.Equal(PrayerTypography.Script.Syriac, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Syrc")));
            Assert.Equal(verse.TransliteratedText, verse.DisplayedText(edition, "Syrc"));
        });
        var torah = Store.Passage("torah", "Genesis 47:28–50:26", edition.Id);
        Assert.Equal(85, torah.Count);
        Assert.Equal(47, torah.First().Chapter);
        Assert.Equal(50, torah.Last().Chapter);
        Assert.All(torah, verse => Assert.False(string.IsNullOrWhiteSpace(verse.TransliteratedText)));
        var psalm = Store.Passage("daily", "Psalm 23:1–3a; 23:3b–4; 23:5–5; 23:6–6", edition.Id);
        Assert.Equal(Enumerable.Range(1, 6), psalm.Select(verse => verse.Verse));
        Assert.All(psalm, verse =>
        {
            Assert.Equal(23, verse.Chapter);
            Assert.Equal(PrayerTypography.Script.Hebrew, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Hebr")));
            Assert.Equal(PrayerTypography.Script.Syriac, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Syrc")));
            Assert.Equal(verse.TransliteratedText, verse.DisplayedText(edition, "Syrc"));
        });
        Assert.Empty(Store.Passage("daily", "Psalm 119:66–66; 119:71–71; 119:75–75; 119:91–91; 119:125–125; 119:130–130", edition.Id));
    }

    [Fact]
    public void ExpandedArabicKeepsPrintedPsalmNumberingAndCompleteGospelVerses()
    {
        const string editionId = "jesuit-arabic-1897";
        var gospel = Store.Passage("daily", "Luke 12:8–12", editionId);
        Assert.Equal(Enumerable.Range(8, 5), gospel.Select(verse => verse.Verse));
        Assert.All(gospel, verse =>
        {
            Assert.Equal(12, verse.Chapter);
            Assert.Equal(PrayerTypography.Script.Arabic, PrayerTypography.ScriptOf(verse.Text));
        });
        var psalm = Store.Passage("daily", "Psalm 23:1–3a; 23:3b–4; 23:5–5; 23:6–6", editionId);
        Assert.Equal(Enumerable.Range(1, 6), psalm.Select(verse => verse.Verse));
        Assert.All(psalm, verse => Assert.Equal(22, verse.Chapter));
        Assert.Equal("مزمور لداود. الرب راعي فلا يعوزني شيء.", psalm.First().Text);
    }

    [Fact]
    public void BundledOldJesuitArabicOpensReviewedPassagesWithoutBorrowingMissingText()
    {
        var edition = Store.ResolveEdition("", "ar-LB");
        Assert.NotNull(edition);
        Assert.Equal("jesuit-arabic-1897", edition.Id);
        Assert.Contains("1897", edition.Name);
        Assert.NotNull(edition.SourceUri);
        Assert.False(string.IsNullOrWhiteSpace(edition.Attribution));

        var verses = Store.Passage("daily", "Luke 1:26–38", edition.Id);
        Assert.Equal(Enumerable.Range(26, 13), verses.Select(verse => verse.Verse));
        Assert.All(verses, verse => Assert.Equal(1, verse.Chapter));
        Assert.Equal("فقالت مريم هاءنذا أمة الرب فليكن لي بحسب قولك. وانصرف الملاك من عندها.", verses.Last().Text);
        var row = new ReadingPassageViewModel(Store, edition, "daily",
            new ReadingCitation("gospel", "Lk", "Luke 1:26–38"), "en", "date", "edition");
        row.IsExpanded = true;
        Assert.True(row.IsRightToLeft);
        Assert.Contains(verses.Last().Text, row.PassageText);

        Assert.Empty(Store.Passage("daily", "Luke 13:1–9", edition.Id));
        Assert.Empty(Store.Passage("torah", "Genesis 47:28–50:26", edition.Id));
    }

    [Fact]
    public void BundledHebrewNewTestamentKeepsSourceVowelsAndTheUnpointedDivineName()
    {
        var edition = Store.ResolveEdition("", "iw-IL");
        Assert.NotNull(edition);
        Assert.Equal("masoretic-delitzsch", edition.Id);
        Assert.DoesNotContain("ללא ניקוד", edition.Attribution);
        Assert.Contains("1901", edition.Attribution);
        Assert.Contains("delitz.fr", edition.Attribution);
        Assert.Equal("https://delitz.fr/12/", edition.SourceURL);

        foreach (var citation in new[] { "Luke 6:27–38", "1 Corinthians 8:1b–7; 8:11–13" })
        {
            var verses = Store.Passage("daily", citation, edition.Id);
            Assert.NotEmpty(verses);
            Assert.All(verses, verse => Assert.True(verse.Text.Any(IsVowelPoint)));
            var row = new ReadingPassageViewModel(Store, edition, "daily",
                new ReadingCitation("reading", "Reading", citation), "en", "date", "edition");
            row.IsExpanded = true;
            Assert.True(row.IsRightToLeft);
            Assert.All(verses, verse => Assert.Contains(verse.Text, row.PassageText));
            Assert.Equal(edition.Attribution, row.Attribution);
            Assert.Equal(edition.SourceUri, row.SourceUri);
        }

        var annunciation = Store.Passage("daily", "Luke 1:26–38", edition.Id);
        const string marks = @"[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]*";
        var names = System.Text.RegularExpressions.Regex.Matches(
            string.Join(" ", annunciation.Select(verse => verse.Text)), $"י{marks}ה{marks}ו{marks}ה{marks}");
        Assert.NotEmpty(names);
        Assert.All(names.Cast<System.Text.RegularExpressions.Match>(), name => Assert.False(name.Value.Any(IsVowelPoint)));

        static bool IsVowelPoint(char character) => character is >= '\u05B0' and <= '\u05BC' or '\u05C7';
    }

    [Fact]
    public void BundledHebrewTorahKeepsCantillationIncludingOnTheDivineName()
    {
        var edition = Store.ResolveEdition("", "iw-IL");
        Assert.Equal("masoretic-delitzsch", edition?.Id);
        var verses = Store.Passage("torah", "Deuteronomy 11:26–16:17", edition!.Id);
        var verse = Assert.Single(verses.Where(item => item.Chapter == 11 && item.Verse == 27));
        Assert.Equal("אֶֽת־הַבְּרָכָ֑ה אֲשֶׁ֣ר תִּשְׁמְע֗וּ אֶל־מִצְוֹת֙ יהו֣ה אֱלֹֽהֵיכֶ֔ם אֲשֶׁ֧ר אָנֹכִ֛י מְצַוֶּ֥ה אֶתְכֶ֖ם הַיֹּֽום׃", verse.Text);
        var row = new ReadingPassageViewModel(Store, edition, "torah",
            new ReadingCitation("torah", "Dt", "Deuteronomy 11:26–16:17"), "en", "date", "edition");
        row.IsExpanded = true;
        Assert.True(row.IsRightToLeft);
        Assert.Contains(verse.Text, row.PassageText);
    }

    [Fact]
    public void BundledMissingLanguageScopeOrCitationNeverBorrowsText()
    {
        Assert.Null(Store.ResolveEdition("", "es"));
        Assert.Null(Store.ResolveEdition("removed-edition", "en"));
        Assert.Empty(Store.Passage("daily", "Luke 6:27–38", "removed-edition"));
        Assert.Empty(Store.Passage("torah", "Luke 6:27–38", "douay-rheims-1899"));
        Assert.Empty(Store.Passage("daily", "Luke 6:27–38 ", "douay-rheims-1899"));
        Assert.Empty(Store.Passage("daily", "Luke 999:1", "douay-rheims-1899"));
        Assert.Equal("ang-dating-biblia-1905", Store.ResolveEdition("", "fil-PH")?.Id);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void PassagesUseTheExpansionPreferenceOnEntryAndContextChangesWhileRefreshKeepsUserChoices(bool expand)
    {
        var previousEdition = AppSettings.ReadingsEditionId;
        var previousExpansion = AppSettings.ExpandReadingsByDefault;
        var previousCalendar = TodayInfoStore.SelectedCalendarId;
        try
        {
            AppSettings.SetReadingsEditionId("douay-rheims-1899");
            AppSettings.SetExpandReadingsByDefault(expand);
            var today = new HomeViewModel(new EmptyPresetStore(), new LiturgicalCalendarService());
            var reader = new DesktopReadingsViewModel(Store);
            today.SelectedTodayDate = new DateTimeOffset(2026, 9, 10, 0, 0, 0, TimeSpan.Zero);
            today.TodayReadings = [new ReadingCitation("gospel", "Lk", "Luke 6:27–38")];
            today.TodayTorahPortion = new TorahPortion("2026-09-12", "Vayechi", null, false,
                [new ReadingCitation("torah", "Gn", "Genesis 47:28–50:26")], null);
            reader.Open(today);
            var first = Assert.Single(reader.Daily);
            Assert.Equal(expand, first.IsExpanded);
            Assert.Equal(expand, first.HasPassage);
            var torah = Assert.Single(reader.Torah);
            Assert.Equal(expand, torah.IsExpanded);
            first.IsExpanded = !expand;
            torah.IsExpanded = !expand;

            // Even if two appointed dates happen to repeat a citation, each day
            // has its own expansion state. An unrelated timer refresh retains it.
            reader.Refresh(today);
            Assert.Same(first, Assert.Single(reader.Daily));
            Assert.Equal(!expand, first.IsExpanded);
            Assert.Same(torah, Assert.Single(reader.Torah));
            Assert.Equal(!expand, torah.IsExpanded);

            AppSettings.SetReadingsEditionId("masoretic-delitzsch");
            reader.Refresh(today);
            Assert.Equal(!expand, Assert.Single(reader.Daily).IsExpanded);
            Assert.Equal(!expand, Assert.Single(reader.Torah).IsExpanded);
            reader.Open(today);
            Assert.Equal(expand, Assert.Single(reader.Daily).IsExpanded);
            Assert.Equal(expand, Assert.Single(reader.Torah).IsExpanded);

            today.SelectedTodayDate = today.SelectedTodayDate!.Value.AddDays(1);
            today.TodayReadings = [new ReadingCitation("gospel", "Lk", "Luke 6:27–38")];
            today.TodayTorahPortion = new TorahPortion("2026-09-12", "Vayechi", null, false,
                [new ReadingCitation("torah", "Gn", "Genesis 47:28–50:26")], null);
            reader.Refresh(today);
            var second = Assert.Single(reader.Daily);
            Assert.NotSame(first, second);
            Assert.Equal(expand, second.IsExpanded);
            Assert.Equal(expand, second.HasPassage);
            var secondTorah = Assert.Single(reader.Torah);
            Assert.Equal(expand, secondTorah.IsExpanded);
            second.IsExpanded = !expand;
            secondTorah.IsExpanded = !expand;

            // A calendar change applies the default to new appointments even when their
            // citations happen to match those in the previous calendar.
            TodayInfoStore.SelectedCalendarId = TodayInfoStore.ResolvedCalendarId == "roman" ? "roman1962" : "roman";
            reader.Refresh(today);
            Assert.Equal(expand, Assert.Single(reader.Daily).IsExpanded);
            Assert.Equal(expand, Assert.Single(reader.Torah).IsExpanded);

            today.SelectedTodayDate = today.MaximumTodayDate;
            reader.Refresh(today);
            Assert.Empty(reader.Daily);
            Assert.Empty(reader.Torah);
        }
        finally
        {
            AppSettings.SetReadingsEditionId(previousEdition);
            AppSettings.SetExpandReadingsByDefault(previousExpansion);
            TodayInfoStore.SelectedCalendarId = previousCalendar;
        }
    }

    private sealed class EmptyPresetStore : IPresetStore
    {
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(new List<Prayer>());
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult<Prayer?>(null);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult<Prayer?>(null);
        public Task SaveAsync(Prayer prayer) => Task.CompletedTask;
        public Task<bool> UpdateIfPresentAsync(Prayer prayer) => Task.FromResult(false);
        public Task DeleteAsync(Prayer prayer) => Task.CompletedTask;
    }
}
