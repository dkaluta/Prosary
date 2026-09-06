using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// PrayerEngine.BuildCustomDevotionSteps is the one generic builder behind every
/// PrayerKind.Custom devotion. These tests exercise it via the real shipped bundles (produced by
/// Shared/tools/make-prosaryprayer.sh from Shared/content/) and carry over the per-devotion
/// assertions from the five deleted hardcoded-engine test files — the step sequences must be
/// byte-for-byte what the hardcoded builders used to emit. Mirrors iOS's
/// CustomDevotionEngineTests.swift / Android's CustomDevotionEngineTest.kt.
/// </summary>
public class CustomDevotionEngineTests : IClassFixture<PrayerPackLoaderFixture>
{
    public CustomDevotionEngineTests(PrayerPackLoaderFixture _)
    {
    }

    private static IReadOnlyList<RosaryStep> BuildSteps(
        string bundleId, string? languageCode,
        bool isEasterSeason = false,
        MarianAntiphonOption seasonalAntiphon = MarianAntiphonOption.SalveRegina,
        string? variantId = null,
        Dictionary<string, string>? customOptions = null,
        bool isLent = false) =>
        PrayerEngine.BuildCustomDevotionSteps(
            bundleId, languageCode, isEasterSeason, seasonalAntiphon, variantId, customOptions,
            rosaryOptions: null, todaysGroup: MysteryGroup.Joyful, dayIndex: 0, isLent: isLent);

    // A repeated step's counter is part of the heading: praying in Hebrew, the Divine Mercy
    // decade reads "(1 מתוך 10)" rather than splicing an English word into right-to-left text.
    // The decade ordinal is part of that heading too: "1st Sorrow" in English, "מכאוב 1" in
    // Hebrew — English is the only one of the six that inflects the number.
    [Fact]
    public void DecadeOrdinalUsesThePrayerLanguage()
    {
        Assert.StartsWith("1st Sorrow", BuildSteps("sevenSorrows", "en")[3].Subtitle);
        Assert.StartsWith("מכאוב 1", BuildSteps("sevenSorrows", "he")[3].Subtitle);
        Assert.StartsWith("Скорбь 1", BuildSteps("sevenSorrows", "ru")[3].Subtitle);
    }

    [Fact]
    public void RepeatCounterUsesThePrayerLanguage()
    {
        Assert.Contains("(1 מתוך 10)", BuildSteps("divineMercyChaplet", "he")[5].Title);
        Assert.Contains("(1 ex 10)", BuildSteps("divineMercyChaplet", "la")[5].Title);
        Assert.Contains("(1 of 10)", BuildSteps("divineMercyChaplet", "en")[5].Title);
    }

    // Trisagion (flat)

    [Fact]
    public void TrisagionProducesTheSixStepSequence()
    {
        var steps = BuildSteps("trisagion", "en");

        Assert.Equal(6, steps.Count);
        Assert.Equal(
            ["Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God"],
            steps.Select(s => s.Title));
        Assert.Contains("Holy God, Holy Mighty One, Holy Immortal One", steps[0].Body);
        Assert.Contains("Glory be to the Father", steps[3].Body);
        Assert.DoesNotContain("Holy Mighty One", steps[4].Body);
    }

    /// <summary>The Mission of St. Gamaliel's Trisagion (sent by Erez 2026-08-06) addresses God
    /// in the second person where the app's own Hebrew declares of him, and heads the prayer
    /// with the Aramaic קדישת. Pinned so their wording — including the ✠▼▲ marks exactly as sent
    /// — cannot drift, and so it stays visibly distinct from the plain-Hebrew form beside
    /// it.</summary>
    [Fact]
    public void TrisagionInTheMissionsRite()
    {
        // Explicitly the Byzantine form: the rite's *default* is now the Syriac one (see
        // TrisagionDefaultFormFollowsThePrayerLanguage); this test pins the wording overlay.
        var mission = BuildSteps("trisagion", "he-x-gamliel", variantId: "byzantine");
        var hebrew = BuildSteps("trisagion", "he");

        Assert.Equal(
            ["קדישת", "קדישת", "קדישת", "השבח לאב", "קדישת", "קדישת"],
            mission.Select(s => s.Title));
        Assert.StartsWith("אַתָּה ✠▼▲ קָדוֹשׁ – אֱלוֹהִים", mission[0].Body);
        Assert.Contains("תְּרַחֵם עָלֵינוּ", mission[0].Body);
        Assert.DoesNotContain("חַיִל", mission[4].Body);

        Assert.NotEqual(hebrew[0].Body, mission[0].Body);
        Assert.Equal("קדוש האלהים", hebrew[0].Title);

        // Not sent by the Mission: the Glory Be itself still reads their wording from the shared
        // table, and everything else falls through to plain Hebrew.
        Assert.Contains("הַשֶּׁבַח לָאָב", mission[3].Body);
    }

    /// <summary>A variant can claim a prayer language as its own (defaultForLanguages), and a
    /// favorite with no explicit choice opens in it: the Mission prays the Syriac form, so
    /// Erez's rite gets it without touching the variant menu. Exact-code match only — plain
    /// Hebrew (the Vicariate, Latin rite) keeps the first-declared default, which per the
    /// canonical tradition order (latin → byzantine → west syriac → armenian → alexandrian →
    /// east syriac) is the earliest tradition the bundle ships: today the Byzantine. An
    /// explicit choice always wins.</summary>
    [Fact]
    public void TrisagionDefaultFormFollowsThePrayerLanguage()
    {
        var gamliel = BuildSteps("trisagion", "he-x-gamliel");
        Assert.Equal(4, gamliel.Count);
        Assert.Equal("יְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא", gamliel[3].Body);
        Assert.Equal(6, BuildSteps("trisagion", "he").Count);
        Assert.Equal(6, BuildSteps("trisagion", "he-x-gamliel", variantId: "byzantine").Count);

        // Classical Syriac claims the same form (2026-08-08): the Qadishat thrice, then the
        // Kurielaison the Syriac liturgy keeps in Greek — Aramaic in Hebrew square script, with
        // the same Aramaic in Syriac letters riding in the script-toggle transliteration.
        var aramaic = BuildSteps("trisagion", "arc");
        Assert.Equal(4, aramaic.Count);
        Assert.Equal("קדישת אלהא", aramaic[0].Title);
        Assert.Equal(
            "קַדּישַת אַלָהָא\nקַדִישַת חַילתָּנָא\nקַדִישַת לָא מִיותָּא אֶתַרחַמעלִין",
            aramaic[0].Body);
        Assert.Equal(
            "ܩܰܕ݁ܝܫܰܬ݂ ܐܰܠܳܗܳܐ\nܩܰܕܺܝܫܰܬ݂ ܚܰܝܠܬ݁ܳܢܳܐ\nܩܰܕܺܝܫܰܬ݂ ܠܳܐ ܡܺܝܘܬ݁ܳܐ ܐܶܬܰܪܚܰܡܥܠܺܝܢ",
            aramaic[0].TransliteratedBody);
        Assert.Equal("קוריאליסונ\nקוריאליסונ\nקוריאליסונ", aramaic[3].Body);
        // Erez supplied the Mission's doxology in both scripts on 2026-08-26. Pin every mark and
        // vowel so the Hebrew-square-script Aramaic and its pointed Syriac rendering cannot drift.
        var glory = BuildSteps("trisagion", "arc", variantId: "byzantine")[3];
        Assert.Equal("שובחא לאבא", glory.Title);
        Assert.Equal(
            "שוּבחָא לַאבָא ✠ ולַברָא וַלרוּחָא קַדישָא\nמֶן עָלַם וַעדַמָא לעָלַם עָלמִין. אַמִין.",
            glory.Body);
        Assert.Equal(
            "ܫܽܘܒܚܳܐ ܠܰܐܒܳܐ ✠ ܘܠܰܒܪܳܐ ܘܰܠܪܽܘܚܳܐ ܩܰܕܝܫܳܐ\nܡܶܢ ܥܳܠܰܡ ܘܰܥܕܰܡܳܐ ܠܥܳܠܰܡ ܥܳܠܡܺܝܢ. ܐܰܡܺܝܢ.",
            glory.TransliteratedBody);
    }

    /// <summary>Erez's Aramaic Nicene Creed (2026-08-31), in Hebrew square and pointed Syriac scripts.</summary>
    [Fact]
    public void AramaicNiceneCreedPreservesBothSuppliedScripts()
    {
        var creed = BuildSteps("rosary", "arc").First(step => step.Title == "מהימנינן");
        Assert.Equal(
            "מהַימנִינַן בחד אַלָהָא, אַבָּא אַחִיד כֻּל, עָבוּדָא דַּשמַיָא ודַארעָא וַדכֻלהֶין אַיללין דמֶתחַזין וַדלָא מֶתחַזיָן, וַבחַד מָריָא יֶשוּע משיחָא יַחחָדָיֶא ברא דַּאַלָהָא, הַו דּמֶן אַבָּא אֶתִילֶד קדדם כלהון עָלמֶא, אַלָהָא מֶן אַלָהָא, נוּהרָא מֶן נוּהרָא, אַלָהָא שַרִירא מֶן אַלָהָא שַרִירָא, יַלִידא ולָא עבִידא, וַשוֶא בֻּאוסִיא לַאבּוּהי, הַו דבּאִידֶה הוֹא כַּל מֶדֶם, הַו דּמֶטֻלָתַן בּנַינשָא, ומֶטֻל פּוּרקָנַן נחֶת מֶן שמַיָא ואֶתגַשַם מֶן רוּחָא קַדִישָא, מֶן מַריַם בּתוּלתָא וַהוֹא בַּרננשֶא, ואֶצטלֶב חלָפִין ביומי פַּנטִיָוס פִילַטָוס, חַש ומִית וְאתקבַר, קם לַתלָתָא יַוַמִין אַיך דַכתִיב, וַסלֶק לַשמַיָא וִיתֶב מֶן יָמִין אַבּוּהי, ותוב אִתֶּא בשוּבחֶה רַבָא לַמן ליַיֶא וַלמִיָתֶא, הַו דַּלמַלכּוּתֶּה שוּלָמָא לָאאית, וַבחַד רוּחָא קַדִישָא דאַיָתַוהי מָריָא מַחינָא דכֻל, הַו דּמֶן אַבָא ובא ננפֶק, ועַם אַבָא ✠ ועַם ברא מֶסתגֶד ומֶשתַבַח, הַו דּמַלֶל בַנכָיֶא, ובַחדָא עִדתָא קַדִישתָא קָתוּלִיקִי וַשלִיחָיתָא, ומַודֶינַן דַחדָא הי מַעמַודָיתָא לשוּבקָנָא דּחַטָהֶא, וַמסַכֶינַן לַקיָמתָא דמִיתֶא וַלִיֶא חַדתֶא דבעָלמָא דַעתִיד. אַמִין.",
            creed.Body);
        Assert.Equal(
            "ܡܗܰܝܡܢܺܝܢܰܢ ܒܚܕ ܐܰܠܳܗܳܐ. ܐܰܒ݁ܳܐ ܐܰܚܺܝܕ݂ ܟ݁ܽܠ. ܥܳܒܽܘܕܳܐ ܕ݁ܰܫܡܰܝܳܐ ܘܕ݂ܰܐܪܥܳܐ ܘܰܕ݂ܟܽܠܗܶܝܢ ܐܰܝܠܠ̈ܝܢ ܕܡܶܬ݂ܚܰܙܝܢ ܘܰܕ݂ܠܳܐ ܡܶܬ݂ܚܰܙܝܳܢ. ܘܰܒ݂ܚܰܕ݂ ܡܳܪܝܳܐ ܝܶܫܽܘܥ ܡܫܝܚܳܐ ܝܰܚܚܳܕ݂ܳܝܶܐ ܒܪܐ ܕ݁ܰܐܰܠܳܗܳܐ. ܗܰܘ ܕ݁ܡܶܢ ܐܰܒ݁ܳܐ ܐܶܬܺܝܠܶܕ݂ ܩ݀ܕܕܡ ܟܠܗ݇ܘܢ ܥܳܠܡ̈ܶܐ. ܐܰܠܳܗܳܐ ܡܶܢ ܐܰܠܳܗܳܐ. ܢܽܘܗܪܳܐ ܡܶܢ ܢܽܘܗܪܳܐ. ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܐ ܡܶܢ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܝܰܠܺܝܕܐ ܘܠܳܐ ܥܒܿܺܝܕܐ. ܘܰܫܘܶܐ ܒ݁ܽܐܘܣܺܝܐ ܠܰܐܒ݁ܽܘܗ̄ܝ. ܗܰܘ ܕܒ݁ܐܺܝܕ݂ܶܗ ܗ݈ܘܳܐ ܟ݁ܰܠ ܡܶܕܶܡ. ܗܰܘ ܕ݁ܡܶܛܽܠܳܬ݂ܰܢ ܒ݁ܢܰܝ̈ܢܫܳܐ. ܘܡܶܛܽܠ ܦ݁ܽܘܪܩܳܢܰܢ ܢܚܶܬ݂ ܡܶܢ ܫܡܰܝܳܐ ܘܐܶܬ݂ܓܰܫܰܡ ܡܶܢ ܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ. ܡܶܢ ܡܰܪܝܰܡ ܒ݁ܬ݂ܽܘܠܬ݂ܳܐ ܘܰܗ݈ܘܳܐ ܒ݁ܰܪܢܢܫܶܐ. ܘܐܶܨܛܠܶܒ݂ ܚܠܳܦ݂ܺܝܢ ܒܝܵܘ̈ܡ̇ܝ ܦ݁ܰܢܛܺܝܳܘܣ ܦܺܝܠܰܛܳܘܣ. ܚܰܫ ܘܡܺܝܬ ܘܶܐܬܩܒܰܪ. ܩܿܡ ܠܰܬ݂ܠܳܬ݂ܳܐ ܝܰܘܰܡܺܝܢ ܐܰܝܟ݂ ܕܰܟܬܺܝܒ. ܘܰܣܠܶܩ ܠܰܫܡܰܝܳܐ ܘܺܝܬ݂ܶܒ݂ ܡܶܢ ܝܳܡܺܝܢ ܐܰܒ݁ܽܘܗ̄ܝ. ܘܬܘܒ ܐܺܬ݁ܶܐ ܒܫܽܘܒ݂ܚܶܗ ܪܰܒܳܐ ܠܰܡܢ ܠܝܰܝܶܐ ܘܰܠܡܺܝܳܬ݂ܶܐ. ܗܰܘ ܕ݁ܰܠܡܰܠܟ݁ܽܘܬ݁ܶܗ ܫܽܘܠܳܡܳܐ ܠܳܐܐܝܬ. ܘܰܒ݂ܚܰܕ݂ ܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ ܕܐܰܝܳܬ݂ܰܘܗ݈ܝ ܡܳܪܝܳܐ ܡܰܚܝܢܳܐ ܕܟܽܠ. ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ✠ ܘܥܰܡ ܒܪܐ ܡܶܣܬܓܶܕ ܘܡܶܫܬ݂ܰܒ݂ܰܚ. ܗܰܘ ܕ݁ܡܰܠܶܠ ܒܰܢ̈ܟܿܳܝܶܐ. ܘܒ݂ܰܚܕܳܐ ܥܺܕܬ݂ܳܐ ܩܰܕܺܝܫܬ݂ܳܐ ܩܳܬ݂ܽܘܠܺܝܩܺܝ ܘܰܫܠܺܝܚܳܝܬ݂ܳܐ. ܘܡܰܘܕ݂ܶܝܢܰܢ ܕܰܚܕ݂ܳܐ ܗ̄ܝ ܡܰܥܡܰܘܕ݂ܳܝܬܳܐ ܠܫܽܘܒܩܳܢܳܐ ܕ݁ܚܰܛܳܗܶܐ. ܘܰܡܣܰܟܶܝܢܰܢ ܠܰܩ݀ܝܳܡܬܳܐ ܕܡܺܝ̈ܬ݂ܶܐ ܘܰܠܺܝ̈ܶܐ ܚܰܕ̈ܬ݂ܶܐ ܕܒ݂ܥܳܠܡܳܐ ܕܰܥܬ݂ܺܝܕ݂. ܐܰܡܺܝܢ.",
            creed.TransliteratedBody);
    }

    /// <summary>Erez's Aramaic Our Father (2026-08-31), in Hebrew square and pointed Syriac scripts.</summary>
    [Fact]
    public void AramaicOurFatherPreservesBothSuppliedScripts()
    {
        var abun = BuildSteps("rosary", "arc").First(step => step.Title == "צלותא מרניתא");
        Assert.Equal(
            "אַבוּן דבַשמַיָא נֶתקַדַש שמָך תִאתֶא מַלכוּתָך נֶהוֶא צֶביָנָך, " +
            "אַיכַנָא דבַשמַיָא אָף בַארעָא, הַבלַן לַחמָא דסוּנקָנַן יַומָנָא, " +
            "וַשבוּק לַן חַובַין וַחטָהַין אַיכַנָא דָאף חנַן שבַקן לחַיָבַין, " +
            "ולָא תַעלַן לנֶסיוּנָא אֶלָא פַצָא לַן מֶן בִישָא, מֶטֻל דדִילָך הִי " +
            "מַלכוּתָא וחַילָא ותֶשבוּחתָא לעָלַם עָלמִין אַמִין.",
            abun.Body.Replace('\n', ' '));
        Assert.Equal(
            "ܐܰܒ݁ܽܘܢ ܕܒܰܫܡܰܝܳܐ ܢܶܬܩܰܕܰܫ ܫܡܳܟ ܬܺܐܬܶܐ ܡܰܠܟܽܘܬܳܟ ܢܶܗܘܶܐ ܨܶܒܝܳܢܳܟ. " +
            "ܐܰܝܟܰܢܳܐ ܕܒܰܫܡܰܝܳܐ ܐܳܦ ܒܰܐܪܥܳܐ. ܗܰܒܠܰܢ ܠܰܚܡܳܐ ܕܣܽܘܢܩܳܢܰܢ ܝܰܘܡܳܢܳܐ. " +
            "ܘܰܫܒܽܘܩ ܠܰܢ ܚܰܘܒܰܝ̈ܢ ܘܰܚܛܳܗܰܝ̈ܢ ܐܰܝܟܰܢܳܐ ܕܳܐܦ ܚܢܰܢ ܫܒܰܩܢ ܠܚܰܝܳܒܰܝ̈ܢ. " +
            "ܘܠܳܐ ܬܰܥܠܰܢ ܠܢܶܣܝܽܘܢܳܐ ܐܶܠܳܐ ܦܰܨܳܐ ܠܰܢ ܡܶܢ ܒܺܝܫܳܐ. " +
            "ܡܶܛܽܠ ܕܕܺܝܠܳܟ ܗܺܝ ܡܰܠܟܽܘܬܳܐ ܘܚܰܝܠܳܐ ܘܬܶܫܒܽܘܚܬܳܐ ܠܥܳܠܰܡ ܥܳܠܡܺܝܢ ܐܰܡܺܝܢ܀",
            abun.TransliteratedBody?.Replace('\n', ' '));
        Assert.Equal(9, abun.Body.Split('\n').Length);
        Assert.NotNull(abun.TransliteratedBody);
        Assert.Equal(abun.Body.Split('\n').Length, abun.TransliteratedBody!.Split('\n').Length);
    }

    /// <summary>Erez's Aramaic Hail Mary (2026-08-31), in Hebrew square and pointed Syriac scripts.</summary>
    [Fact]
    public void AramaicHailMaryPreservesBothSuppliedScripts()
    {
        var hailMary = BuildSteps("rosary", "arc")
            .First(step => step.Title.StartsWith("שלם לך מרים", StringComparison.Ordinal));
        Assert.Equal(
            "שלָם לֶך מַריַם מַליַת טַיבוּתָא, מָרַן עַמֶך מבַרַכתָא אַנת בנֶשָא " +
            "וַמבַרַך הוּ פִירָא דַבכַרסֶך מָרַן יֶשוּע משִיחָא, מָרַת מַריַם יָלדַת " +
            "אַלָהָא אַפִיס חלָפַין חנַן חַטָיָא, הָשָא וַבכֻלזבַן וַלעָלַם עָלמִין אַמִין.",
            hailMary.Body.Replace('\n', ' '));
        Assert.Equal(
            "ܫܠܳܡ ܠܶܟ ܡܰܪܝܰܡ ܡܰܠܝܰܬ ܛܰܝܒܽܘܬܳܐ, ܡܳܪܰܢ ܥܰܡܶܟ ܡܒܰܪܰܟܬܳܐ ܐܰܢܬ ܒܢܶܫܳܐ " +
            "ܘܰܡܒܰܪܰܟ ܗܽܘ ܦܺܝܪܳܐ ܕܰܒܟܰܪܣܶܟ ܡܳܪܰܢ ܝܶܫܽܘܥ ܡܫܺܝܚܳܐ, ܡܳܪܰܬ ܡܰܪܝܰܡ ܝܳܠܕܰܬ " +
            "ܐܰܠܳܗܳܐ ܐܰܦܺܝܣ ܚܠܳܦܰܝܢ ܚܢܰܢ ܚܰܛܳܝܳܐ, ܗܳܫܳܐ ܘܰܒܟܽܠܙܒܰܢ ܘܰܠܥܳܠܰܡ ܥܳܠܡܺܝܢ ܐܰܡܺܝܢ.",
            hailMary.TransliteratedBody?.Replace('\n', ' '));
        Assert.Equal(7, hailMary.Body.Split('\n').Length);
        Assert.NotNull(hailMary.TransliteratedBody);
        Assert.Equal(hailMary.Body.Split('\n').Length, hailMary.TransliteratedBody!.Split('\n').Length);
    }

    [Fact]
    public void TrisagionImagesMatchTheDevotionJsonImageKeys()
    {
        var steps = BuildSteps("trisagion", "en");

        Assert.Equal(
            ["jesus_portrait", "jesus_portrait", "jesus_portrait", "glory_be", "jesus_portrait", "jesus_portrait"],
            steps.Select(s => s.ImageOverrideKey));
    }

    // Angelus (flat + Eastertide swap)

    [Fact]
    public void AngelusStandardFormOutsideEastertide()
    {
        var steps = BuildSteps("angelus", "en");

        Assert.Equal(7, steps.Count);
        Assert.Equal(
            [
                "The Annunciation", "Hail Mary",
                "The Fiat", "Hail Mary",
                "The Incarnation", "Hail Mary",
                "Let Us Pray",
            ],
            steps.Select(s => s.Title));
        Assert.Contains("The Angel of the Lord declared unto Mary", steps[0].Body);
        Assert.Contains("**And she conceived of the Holy Spirit.**", steps[0].Body);
        Assert.Contains("Hail Mary,\nfull of grace", steps[1].Body);
        Assert.Contains("Pour forth, we beseech Thee", steps[^1].Body);
        Assert.DoesNotContain(steps, s => s.Body.Contains("Queen of Heaven"));
        Assert.All(steps, s => Assert.Equal("joyful_01_annunciation", s.ImageOverrideKey));
    }

    [Fact]
    public void AngelusReginaCaeliSubstitutionDuringEastertide()
    {
        var steps = BuildSteps("angelus", "en", isEasterSeason: true);

        var step = Assert.Single(steps);
        Assert.Equal("Regina Caeli", step.Title);
        Assert.Contains("Queen of Heaven, rejoice", step.Body);
        Assert.Contains("Rejoice and be glad, O Virgin Mary", step.Body);
        Assert.DoesNotContain("Pour forth, we beseech Thee", step.Body);
        Assert.Equal("madonna_and_child", step.ImageOverrideKey);
    }

    [Fact]
    public void AngelusFollowsDefaultPrecedenceWhenLanguageIsUnknown()
    {
        var steps = BuildSteps("angelus", "xx");
        Assert.Contains("The Angel of the Lord declared unto Mary", steps[0].Body);
    }

    // Stations of the Cross (flat, translated titles)

    [Fact]
    public void StationsProducesEighteenStepsWithTranslatedTitlesAndOrdinals()
    {
        var steps = BuildSteps("stationsOfTheCross", "en");

        Assert.Equal(18, steps.Count);
        Assert.Equal("Sign of the Cross", steps[0].Title);
        Assert.Equal("Opening Prayer", steps[1].Title);
        Assert.Equal("Jesus is Condemned to Death", steps[2].Title);
        Assert.Equal("1st Station", steps[2].Subtitle);
        Assert.Equal("14th Station", steps[15].Subtitle);
        Assert.Equal("Closing Prayer", steps[16].Title);
        // Anima Christi closes the Way of the Cross — a shared "main" prayer (hardcoded in all
        // six languages), so the bundle references it without shipping its own text.
        Assert.Equal("Anima Christi", steps[^1].Title);
        Assert.Contains("Soul of Christ, sanctify me", steps[^1].Body);
        Assert.Contains("We adore You, O Christ", steps[2].Acclamation);
        Assert.DoesNotContain("We adore You", steps[2].Body);
        Assert.Contains("**Because by Your holy Cross You have redeemed the world.**", steps[2].Acclamation);
        Assert.Equal("station_01_condemned_to_death", steps[2].ImageOverrideKey);
        // No bead fields anywhere — Stations is a flat devotion.
        Assert.All(steps, s =>
        {
            Assert.Null(s.DecadeIndex);
            Assert.Null(s.HailMaryIndexInDecade);
        });
    }

    // Via Lucis (flat, 14 scriptural stations)

    /// <summary>Cross + 14 stations + Regina Caeli + closing cross — mirrors iOS's
    /// testViaLucisSeventeenStepSequence.</summary>
    [Fact]
    public void ViaLucisSeventeenStepSequence()
    {
        var steps = BuildSteps("viaLucis", "en");
        Assert.Equal(17, steps.Count);
        Assert.Equal("Sign of the Cross", steps[0].Title);
        Assert.Equal("Jesus Rises from the Dead", steps[1].Title);
        Assert.Equal("1st Station", steps[1].Subtitle);
        Assert.Equal("glorious_01_resurrection", steps[1].ImageOverrideKey);
        Assert.Contains("Because by Your holy Cross and Resurrection", steps[1].Acclamation);
        Assert.Contains("— Matthew 28:1–7 (Douay-Rheims)", steps[1].Body);
        Assert.All(steps.Skip(1).Take(14), s => Assert.True(s.IsScripture));
        Assert.Contains("[…]", steps[4].Body);
        Assert.Equal("Jesus Strengthens the Faith of Thomas", steps[8].Title);
        Assert.Equal("The Holy Spirit Descends at Pentecost", steps[14].Title);
        Assert.Equal("Regina Caeli", steps[15].Title);
        Assert.Contains("Queen of Heaven, rejoice", steps[15].Body);
        // Once clipped mid-sentence by a bad authoring-time extraction — endings pinned.
        Assert.Contains("Pray for us to God, alleluia.", steps[15].Body);
        Assert.EndsWith("through the same Christ our Lord. Amen.", steps[15].Body);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void ViaLucisLatinBodiesComeFromTheVulgate()
    {
        var steps = BuildSteps("viaLucis", "la");
        Assert.Equal("Iesus a mortuis resurgit", steps[1].Title);
        Assert.Contains("— Matth. 28:1–7 (Vulgata)", steps[1].Body);
        Assert.Contains("Regina caeli, laetare, alleluia.", steps[15].Body);
    }

    /// <summary>The traditional stations' meditations are quoted scripture in ar/he/ru/tl but
    /// Liguori prose in la/en — isScriptureByLanguage picks the typeface per session
    /// language.</summary>
    [Fact]
    public void TraditionalStationsScriptureFlagFollowsTheLanguage()
    {
        Assert.True(BuildSteps("stationsOfTheCross", "he")[2].IsScripture);
        Assert.False(BuildSteps("stationsOfTheCross", "en")[2].IsScripture);
    }

    // Stations variants (traditional vs. scriptural)

    /// <summary>An unknown/null variantId resolves to the default (first) variant — the
    /// traditional set.</summary>
    [Fact]
    public void StationsDefaultVariantIsTheTraditionalSet()
    {
        Assert.Equal(
            BuildSteps("stationsOfTheCross", "en", variantId: null).Select(s => s.Title),
            BuildSteps("stationsOfTheCross", "en", variantId: "traditional").Select(s => s.Title));
        Assert.Equal(18, BuildSteps("stationsOfTheCross", "en", variantId: "no-such-variant").Count);
    }

    /// <summary>The scriptural (St. John Paul II) variant — same 18-step frame (shared
    /// opening/closing/Anima Christi), fourteen different scenes with scriptural meditations.</summary>
    [Fact]
    public void StationsScripturalVariantSequence()
    {
        var steps = BuildSteps("stationsOfTheCross", "en", variantId: "scriptural");
        Assert.Equal(18, steps.Count);
        Assert.Equal("Jesus Prays in the Garden of Gethsemane", steps[2].Title);
        Assert.Equal("1st Station", steps[2].Subtitle);
        Assert.Equal("sorrowful_01_agony_in_the_garden", steps[2].ImageOverrideKey);
        Assert.Contains("We adore You, O Christ", steps[2].Acclamation);
        Assert.DoesNotContain("We adore You", steps[2].Body);
        Assert.Contains("— Mark 14:32–36 (Douay-Rheims)", steps[2].Body);
        Assert.Equal("scriptural_02_kiss_of_judas", steps[3].ImageOverrideKey);
        Assert.Equal("Jesus Promises His Kingdom to the Good Thief", steps[12].Title);
        Assert.Equal("seven_sorrows_05_crucifixion", steps[13].ImageOverrideKey);
        Assert.Equal("Anima Christi", steps[^1].Title);
        // The fourteen station bodies are quoted Gospel passages, so they render in the
        // scripture typeface; the shared opening/closing prayers do not.
        Assert.All(steps.Skip(2).Take(14), s => Assert.True(s.IsScripture));
        Assert.False(steps[1].IsScripture);
        Assert.False(steps[16].IsScripture);
    }

    // Franciscan Crown (rosary type, 7×10 + antiphon)

    /// <summary>The Crown's two optional closing devotions (the 72-completion Hail Marys, the
    /// Our Father for the Pope's intentions) default ON — the untouched 90-step sequence below
    /// is the proof that adding options.json changed nothing. Turning them off drops exactly
    /// those steps.</summary>
    [Fact]
    public void FranciscanCrownOptionsDropTheirClosingSteps()
    {
        var noSeventyTwo = BuildSteps(
            "franciscanCrown", "en",
            customOptions: new Dictionary<string, string> { ["seventyTwoHailMarys"] = "false" });
        Assert.Equal(88, noSeventyTwo.Count);
        Assert.DoesNotContain(noSeventyTwo, s => s.Subtitle == "For the years of Our Lady's life");

        var neither = BuildSteps(
            "franciscanCrown", "en",
            customOptions: new Dictionary<string, string>
            {
                ["seventyTwoHailMarys"] = "false",
                ["popeIntentions"] = "false",
            });
        Assert.Equal(87, neither.Count);
        Assert.DoesNotContain(neither, s => s.Subtitle == "For the intentions of the Holy Father");

        // An override for a key the bundle doesn't declare is ignored, not an error.
        Assert.Equal(90, BuildSteps(
            "franciscanCrown", "en",
            customOptions: new Dictionary<string, string> { ["noSuchOption"] = "false" }).Count);
    }

    [Fact]
    public void ConditionExpressionEvaluation()
    {
        var values = new Dictionary<string, string>
        {
            ["fatima"] = "true",
            ["creed"] = "false",
            ["antiphon"] = "reginaCaeli",
        };
        Assert.True(PrayerEngine.EvaluateCondition("fatima", values));
        Assert.False(PrayerEngine.EvaluateCondition("creed", values));
        Assert.False(PrayerEngine.EvaluateCondition("!fatima", values));
        Assert.True(PrayerEngine.EvaluateCondition("!creed", values));
        Assert.True(PrayerEngine.EvaluateCondition("antiphon=reginaCaeli", values));
        Assert.False(PrayerEngine.EvaluateCondition("antiphon=salveRegina", values));
        Assert.False(PrayerEngine.EvaluateCondition("missing", values));
    }

    [Fact]
    public void FranciscanCrownNinetyStepSequence()
    {
        var steps = BuildSteps("franciscanCrown", "en");

        Assert.Equal(90, steps.Count);
        Assert.Equal("Sign of the Cross", steps[0].Title);
        // 7 decades of announce + Our Father + 10 Hail Marys.
        Assert.Equal(Enumerable.Range(0, 7), steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct().OrderBy(i => i));
        Assert.Equal(10, steps.Where(s => s.HailMaryIndexInDecade.HasValue).Max(s => s.HailMaryIndexInDecade!.Value));
        // Joy 1 announcement reuses the shared Rosary mystery text/image cross-bundle.
        Assert.Equal("The Annunciation", steps[1].Title);
        Assert.Equal("1st Joy", steps[1].Subtitle);
        Assert.True(steps[1].IsScripture);
        Assert.Equal("joyful_01_annunciation", steps[1].ImageOverrideKey);
        // Joy 4 is the Crown's own Adoration of the Magi.
        var joy4 = steps.First(s => s.Subtitle == "4th Joy");
        Assert.Equal("The Adoration of the Magi", joy4.Title);
        Assert.Equal("franciscan_04_adoration_of_the_magi", joy4.ImageOverrideKey);
        // The Our Father inside a decade uses the decade's own art (unlike the Rosary).
        Assert.Equal("Our Father", steps[2].Title);
        Assert.Equal("joyful_01_annunciation", steps[2].ImageOverrideKey);
        // Closing (opening 1 + 7×12 decades = indices 0…84): 2 Hail Marys + Our Father +
        // seasonal antiphon + cross.
        Assert.Equal("Hail Mary (1 of 2)", steps[85].Title);
        Assert.Equal("For the years of Our Lady's life", steps[85].Subtitle);
        Assert.Null(steps[85].DecadeIndex);
        Assert.Null(steps[85].HailMaryIndexInDecade);
        Assert.Equal("Our Father", steps[87].Title);
        Assert.Equal("For the intentions of the Holy Father", steps[87].Subtitle);
        Assert.True(steps[88].IsAntiphon);
        Assert.Equal("madonna_and_child", steps[88].ImageOverrideKey);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void FranciscanCrownAntiphonFollowsTheSeason()
    {
        var paschal = BuildSteps("franciscanCrown", "en", seasonalAntiphon: MarianAntiphonOption.ReginaCaeli);
        Assert.Equal("Regina Caeli", paschal[88].Title);
        Assert.True(paschal[88].IsAntiphon);
    }

    // Seven Sorrows (rosary type, 7×7)

    [Fact]
    public void SevenSorrowsSixtyNineStepSequence()
    {
        var steps = BuildSteps("sevenSorrows", "en");

        Assert.Equal(69, steps.Count);
        Assert.Equal(Enumerable.Range(0, 7), steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct().OrderBy(i => i));
        Assert.Equal(7, steps.Where(s => s.HailMaryIndexInDecade.HasValue).Max(s => s.HailMaryIndexInDecade!.Value));
        Assert.Equal("The Prophecy of Simeon", steps[1].Title);
        Assert.Equal("1st Sorrow", steps[1].Subtitle);
        // The Meeting on the Way (4th sorrow) is the one traditional non-Gospel scene.
        var announcements = steps.Where(s => s.DecadeIndex.HasValue && !s.HailMaryIndexInDecade.HasValue && s.Title != "Our Father").ToList();
        Assert.Equal(7, announcements.Count);
        Assert.False(announcements[3].IsScripture);
        Assert.All(announcements.Where((_, i) => i != 3), a => Assert.True(a.IsScripture));
        // Closing: 3 Hail Marys for the tears, the composed Our Lady of Sorrows body, cross.
        Assert.Equal("Hail Mary (1 of 3)", steps[64].Title);
        Assert.Equal("For the tears of Our Lady", steps[64].Subtitle);
        Assert.Equal("Our Lady of Sorrows", steps[67].Title);
        Assert.Contains("**That we may be made worthy of the promises of Christ.**", steps[67].Body);
        Assert.DoesNotContain(steps, s => s.IsAntiphon);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    /// <summary>The sorrow texts live only in the bundle (they were deleted from the hardcoded
    /// tables) — a language the bundle doesn't declare must follow the configured precedence
    /// (English first by default), not leak raw imageKeys as titles.</summary>
    [Fact]
    public void SevenSorrowsFollowsDefaultPrecedenceForAnUndeclaredLanguage()
    {
        var steps = BuildSteps("sevenSorrows", "xx");
        Assert.Equal("The Prophecy of Simeon", steps[1].Title);
    }

    // Divine Mercy Chaplet (rosary type, no announcements, fixed image)

    [Fact]
    public void DivineMercySixtyThreeStepSequence()
    {
        var steps = BuildSteps("divineMercyChaplet", "en");

        Assert.Equal(63, steps.Count);
        Assert.Equal(
            ["Sign of the Cross", "Our Father", "Hail Mary", "Apostles' Creed"],
            steps.Take(4).Select(s => s.Title));
        Assert.Equal(Enumerable.Range(0, 5), steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct().OrderBy(i => i));
        Assert.Equal("Eternal Father, I Offer You...", steps[4].Title);
        Assert.Equal("1st Decade", steps[4].Subtitle);
        Assert.Equal("For the Sake of His Sorrowful Passion (1 of 10)", steps[5].Title);
        Assert.Equal("Holy God, Holy Mighty One, Holy Immortal One (1 of 3)", steps[59].Title);
        Assert.Null(steps[59].DecadeIndex);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
        // Every step reuses the single Divine Mercy image.
        Assert.All(steps, s => Assert.Equal("divine_mercy_image", s.ImageOverrideKey));
    }

    // O Antiphons (days)

    /// <summary>The one shipped days-type bundle: seven evenings of Advent Vespers, each a
    /// reading, the antiphon, the Magnificat, the Glory Be, and the antiphon again.</summary>
    [Fact]
    public void OAntiphonsDayIsSelectedByTheDayIndex()
    {
        static IReadOnlyList<RosaryStep> Day(int index, string language = "en") =>
            PrayerEngine.BuildCustomDevotionSteps(
                "oAntiphons", language, isEasterSeason: false,
                MarianAntiphonOption.SalveRegina, dayIndex: index);

        Assert.Equal(
            ["A Reading", "O Wisdom", "The Magnificat", "Glory Be", "O Wisdom"],
            Day(0).Select(s => s.Title));
        Assert.Equal(
            ["A Reading", "O Root of Jesse", "The Magnificat", "Glory Be", "O Root of Jesse"],
            Day(2).Select(s => s.Title));
        Assert.Equal("O Emmanuel", Day(6)[1].Title);
        Assert.Equal("O Radix Iesse", Day(2, "la")[1].Title);
        Assert.Contains("come to save us, O Lord our God", Day(6)[1].Body);
        // The reading and the canticle are Scripture; the antiphon is not.
        Assert.True(Day(0)[0].IsScripture);
        Assert.True(Day(0)[2].IsScripture);
        Assert.False(Day(0)[1].IsScripture);
        // Past the last day the engine clamps rather than emitting nothing.
        Assert.Equal("O Emmanuel", Day(99)[1].Title);
    }

    /// <summary>The declarations the Pray row and the resumption logic read.</summary>
    [Fact]
    public void OAntiphonsDeclaresItselfASeriesOfSevenDays()
    {
        var definition = PrayerPackStore.Definition("oAntiphons");
        Assert.Equal(7, definition?.Days?.Count);
        Assert.Equal("series", definition?.DayProgression);
        Assert.Equal("12-17", definition?.SuggestedStart);
        Assert.Equal("18:00", definition?.SuggestedReminderTime);
        Assert.Equal("angelus", definition?.SuggestedNext);
        Assert.Equal("17 December", definition?.Days?[0].Period);
        Assert.Equal("O Sapientia", definition?.Days?[0].Name);
    }

    /// <summary>The Divine Mercy chaplet's Hebrew is the Latin Patriarchate's own — approved by
    /// Patriarch Michel Sabbah in 2003 — so it is pinned here rather than left to drift.</summary>
    [Fact]
    public void DivineMercyHebrewIsTheApprovedText()
    {
        var steps = BuildSteps("divineMercyChaplet", "he");
        Assert.Contains(steps, s => s.Body.StartsWith("אב נצחי שבשמים, אני מציע בפניך"));
        Assert.Contains(steps, s => s.Body == "למען אהבתו אותנו בייסוריו רחם עלינו ועל העולם כולו.");
        Assert.Contains(steps, s => s.Body.StartsWith("קדוש אלוהינו, קדוש וחזק"));
    }

    // The invitatory, and the Mission's Hebrew

    /// <summary>The Rosary may open with "O God, come to my assistance" — off by default, and
    /// the Alleluia leaves it during Lent, which is what the "invitatory &amp; !isLent" gate is
    /// for.</summary>
    [Fact]
    public void InvitatoryIsOptionalAndDropsItsAlleluiaInLent()
    {
        Assert.DoesNotContain("come to my assistance", BuildSteps("rosary", "en")[1].Body);

        var on = BuildSteps("rosary", "en", customOptions: new() { ["invitatory"] = "true" });
        Assert.Equal("O God, Come to My Assistance", on[1].Title);
        Assert.Contains("O Lord, make haste to help me", on[1].Body);
        Assert.Contains("Glory be to the Father", on[1].Body);
        Assert.EndsWith("Alleluia.", on[1].Body);

        var inLent = BuildSteps("rosary", "en", customOptions: new() { ["invitatory"] = "true" }, isLent: true);
        Assert.Contains("Glory be to the Father", inLent[1].Body);
        Assert.DoesNotContain("Alleluia", inLent[1].Body);
    }

    [Fact]
    public void ConjoinedConditionsRequireEveryTerm()
    {
        var values = new Dictionary<string, string>
        {
            ["invitatory"] = "true", ["isLent"] = "false", ["antiphon"] = "reginaCaeli",
        };
        Assert.True(PrayerEngine.EvaluateCondition("invitatory & !isLent", values));
        Assert.False(PrayerEngine.EvaluateCondition("invitatory & isLent", values));
        Assert.True(PrayerEngine.EvaluateCondition("invitatory & antiphon=reginaCaeli", values));
        Assert.False(PrayerEngine.EvaluateCondition("invitatory & antiphon=salveRegina", values));
        // A single term still parses exactly as before.
        Assert.True(PrayerEngine.EvaluateCondition("invitatory", values));
    }

    /// <summary>The shipped Trisagion was always the Byzantine form; it just never said so.
    /// Erez prays the Syriac one — the acclamation thrice, then Lord-have-mercy thrice.
    /// Byzantine stays first so the default sequence is byte-identical; plain Hebrew's Kyrie
    /// falls back to the bundle's Latin until the Vicariate's wording arrives.</summary>
    [Fact]
    public void TrisagionSyriacVariant()
    {
        var syriac = BuildSteps("trisagion", "en", variantId: "syriac");
        Assert.Equal(4, syriac.Count);
        Assert.Equal(
            ["Holy God", "Holy God", "Holy God", "Lord, Have Mercy"],
            syriac.Select(s => s.Title));
        // The Kyrie is ONE composed step — the threefold form is a single text, so repeating it
        // would pray nine invocations.
        Assert.Equal("Lord, have mercy.\nChrist, have mercy.\nLord, have mercy.", syriac[3].Body);
        Assert.DoesNotContain(syriac, s => s.Body.Contains("Glory be"));

        // The Vicariate's Hebrew is the full threefold form in one line, exactly as sent;
        // Erez's rite overlays the same slot with his own line said thrice.
        var hebrewKyrie = BuildSteps("trisagion", "he", variantId: "syriac")[3];
        Assert.Equal("יֵשׁוּעַ שְׁמָעֵנוּ, הַמָּשִׁיחַ עָזְרֵנוּ, הָאָדוֹן חָנֵּנוּ.", hebrewKyrie.Body);
        Assert.Equal("ישוע שמענו", hebrewKyrie.Title);
        Assert.Equal("יְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא", BuildSteps("trisagion", "he-x-gamliel", variantId: "syriac")[3].Body);
    }

    /// <summary>The Vicariate's Hebrew prayerbook leads each of the three acclamations with a
    /// cross, and gives the short form none. The asymmetry is the point: it is exactly what an
    /// editor would "tidy up" later, so both halves are pinned. Hebrew only — the other languages
    /// keep the plain text until someone has seen a prayerbook in those.</summary>
    [Fact]
    public void TrisagionCrossesFollowTheVicariatesPrayerbook()
    {
        var hebrew = BuildSteps("trisagion", "he");
        Assert.Equal(3, hebrew[0].Body.Count(c => c == '\u2720'));
        Assert.StartsWith("\u2720 \u05E7\u05B8\u05D3\u05D5\u05B9\u05E9\u05C1", hebrew[0].Body);
        Assert.DoesNotContain("\u2720", hebrew[4].Body);

        foreach (var language in new[] { "la", "en", "ar", "ru", "tl" })
        {
            Assert.DoesNotContain("\u2720", BuildSteps("trisagion", language)[0].Body);
        }
    }

    /// <summary>The Mission of St. Gamaliel's wording overlays plain Hebrew key by key — their
    /// Creed is the Nicene one, and anything they have not sent still reads in the app's
    /// Hebrew.</summary>
    [Fact]
    public void GamalielVariantOverlaysHebrew()
    {
        var variant = BuildSteps("rosary", "he-x-gamliel", customOptions: new() { ["apostlesCreed"] = "true" });
        Assert.Contains("אָנוּ מַאֲמִינִים", variant[1].Body);
        Assert.Equal("מאמינים של ניקאה", variant[1].Title);
        Assert.Contains(variant, step => step.Body.Contains("שָׁלוֹם לָךְ מִרְיָם"));

        // Headings belong to the rite that uses them: the Mission's in the Mission's rite, the
        // app's own in plain Hebrew.
        var hebrew = BuildSteps("rosary", "he", customOptions: new() { ["apostlesCreed"] = "true" });
        Assert.Equal("אות הצלב", variant[0].Title);
        Assert.Equal("סימן הצלב", hebrew[0].Title);
        Assert.Equal("אני מאמין", hebrew[1].Title);
        Assert.Contains(variant, s => s.Title.StartsWith("שלום לך מרים", StringComparison.Ordinal));
        Assert.Contains(hebrew, s => s.Title.StartsWith("שמחי מרים", StringComparison.Ordinal));
        Assert.Contains(variant, s => s.Title == "השבח לאב");
        Assert.Contains(hebrew, s => s.Title == "כבוד לאב");

        // Not sent by the Mission: the Fatima prayer still reads in the app's Hebrew.
        static string? Fatima(IReadOnlyList<RosaryStep> steps) =>
            steps.FirstOrDefault(s => s.Title.Contains("הו ישוע"))?.Body;
        Assert.Equal(Fatima(hebrew), Fatima(variant));

        // The mysteries are announced in Hebrew too. The Mission ships no mystery texts of its
        // own, and the announcement is the one step whose body is quoted Scripture — before the
        // base language step in MysteryTranslations.Get it fell past plain Hebrew all the way to
        // Latin, so the rite prayed its Rosary in Hebrew but heard every mystery announced in
        // Latin.
        static RosaryStep? Announcement(IReadOnlyList<RosaryStep> steps) =>
            steps.FirstOrDefault(s => s.Mystery is not null);
        Assert.NotNull(Announcement(variant));
        Assert.Equal(Announcement(hebrew)?.Title, Announcement(variant)?.Title);
        Assert.Equal(Announcement(hebrew)?.Body, Announcement(variant)?.Body);
        Assert.NotEqual(Announcement(BuildSteps("rosary", "la"))?.Body, Announcement(variant)?.Body);
    }

    /// <summary>One Hebrew language choice exposes two separately preserved prayer traditions.</summary>
    [Fact]
    public void RitesAreListedUnderTheirLanguage()
    {
        Assert.Equal(["he", "he-x-gamliel"], LanguageCatalog.All.Where(l => l.Code.StartsWith("he")).Select(l => l.Code));
        Assert.Equal(
            ["la", "en", "he"],
            LanguageCatalog.AvailableOptions(["la", "he", "en"]).Select(l => l.Code));
        Assert.Equal(["he", "he-x-gamliel"], LanguageCatalog.Rites("he").Select(r => r.Code));
        Assert.Equal(["he", "he-x-gamliel"], LanguageCatalog.Rites("he-x-gamliel").Select(r => r.Code));
        Assert.Empty(LanguageCatalog.Rites("la"));

        // A rite resolves as its language for display, keeps its own code, and reads right-to-left.
        var resolved = LanguageCatalog.Resolve("he-x-gamliel");
        Assert.Equal("he-x-gamliel", resolved.Code);
        Assert.Equal("עברית", resolved.NativeName);
        Assert.True(resolved.IsRightToLeft);
    }

    [Fact]
    public void LanguageFallbackOrderKeepsBaseFirstAndLatinLast()
    {
        var original = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder(["ru", "en", "ar", "he", "he-x-gamliel", "arc", "el", "es", "tl", "la"]);
            var chain = LanguageCatalog.FallbackChain("he-x-gamliel");
            Assert.Equal(new[] { "he-x-gamliel", "he", "ru", "en" }, chain.Take(4));
            Assert.Equal("la", chain.Last());
        }
        finally
        {
            AppSettings.SetLanguageFallbackOrder(original);
        }
    }

    // Structural guards

    [Fact]
    public void UnknownBundleIdProducesNoSteps()
    {
        var steps = BuildSteps("not-a-real-bundle", "en");
        Assert.Empty(steps);
    }

    /// <summary>The bead track assumes the closing cross is the literal last step and decade
    /// indices are dense — guard every shipped rosary-type bundle at once.</summary>
    [Fact]
    public void EveryRosaryTypeBundleSatisfiesTheBeadTrackInvariants()
    {
        foreach (var bundleId in PrayerPackStore.CustomDevotionIds())
        {
            var definition = PrayerPackStore.Definition(bundleId);
            Assert.NotNull(definition);
            if (definition!.Type != CustomDevotionDefinition.DevotionType.Rosary)
            {
                continue;
            }

            var steps = BuildSteps(bundleId, "en");
            Assert.True(steps[0].Title == "Sign of the Cross", $"{bundleId}: opening cross must be step 0");
            if (definition.HasClosingCross == true)
            {
                Assert.True(steps[^1].Title == "Sign of the Cross", $"{bundleId}: closing cross must be last");
            }

            var indices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).ToList();
            Assert.True(
                indices.ToHashSet().SetEquals(Enumerable.Range(0, indices.Max() + 1)),
                $"{bundleId}: decadeIndex must be dense");
            Assert.True(steps.Count(s => s.IsAntiphon) <= 1, $"{bundleId}: at most one antiphon");
            // Minors carry indices; announcements/majors never do.
            foreach (var step in steps.Where(s => s.HailMaryIndexInDecade.HasValue))
            {
                Assert.True(step.DecadeIndex.HasValue, $"{bundleId}: minor steps must sit inside a decade");
            }
        }
    }
}
