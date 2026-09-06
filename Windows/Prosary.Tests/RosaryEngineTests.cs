using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>The Rosary now builds from the rosary bundle's devotion.json (with RosaryOptions
/// mapped onto the bundle's option values), so these tests need the packs loaded exactly like
/// CustomDevotionEngineTests — hence the fixture.</summary>
public class RosaryEngineTests : IClassFixture<PrayerPackLoaderFixture>
{
    private readonly PrayerEngine _engine = new(new LiturgicalCalendarService());

    public RosaryEngineTests(PrayerPackLoaderFixture _)
    {
    }

    private static Prayer SpecificRosary(RosaryOptions? options = null, string languageCode = "en") => new()
    {
        Kind = PrayerKind.Rosary,
        LanguageCode = languageCode,
        Rosary = options ?? new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
        },
    };

    [Fact]
    public void AramaicReadingAidsSurviveEveryDecadeAndPresenterMode()
    {
        var steps = _engine.BuildSteps(SpecificRosary(languageCode: "arc"));
        foreach (var (key, expectedCount) in new[] { ("paterNoster", 5), ("aveMaria", 50), ("gloriaPatri", 5) })
        {
            var body = PrayerPackStore.ResolveBodyText("rosary", "arc", key);
            var readingAid = PrayerPackStore.Transliteration("rosary", "arc", key);
            Assert.NotNull(readingAid);
            var beads = steps.Where(step => step.DecadeIndex is not null && step.Body == body).ToList();
            Assert.Equal(expectedCount, beads.Count);
            Assert.All(beads, step => Assert.Equal(readingAid, step.TransliteratedBody));
        }
        var presenter = _engine.BuildSteps(SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            PresenterMode = true,
        }, "arc"));
        var combined = presenter.Where(step => step.HailMaryIndexInDecade is not null).ToList();
        var combinedAid = string.Join("\n\n", new[] { "aveMaria", "gloriaPatri" }.Select(key =>
            PrayerPackStore.Transliteration("rosary", "arc", key)));
        Assert.Equal(5, combined.Count);
        Assert.All(combined, step => Assert.Equal(combinedAid, step.TransliteratedBody));
    }

    [Fact]
    public void BuildSteps_SpecificGroup_HasFiveDecades()
    {
        var steps = _engine.BuildSteps(SpecificRosary());
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal([0, 1, 2, 3, 4], decadeIndices.OrderBy(i => i));
    }

    [Fact]
    public void BuildSteps_FifteenMystery_HasFifteenDecades()
    {
        var prayer = SpecificRosary(new RosaryOptions { MysterySelectionMode = MysterySelectionMode.FifteenMystery });
        var steps = _engine.BuildSteps(prayer);
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal(15, decadeIndices.Count());
        Assert.Equal(0, decadeIndices.Min());
        Assert.Equal(14, decadeIndices.Max());
    }

    [Fact]
    public void BuildSteps_TwentyMystery_HasTwentyDecades()
    {
        var prayer = SpecificRosary(new RosaryOptions { MysterySelectionMode = MysterySelectionMode.TwentyMystery });
        var steps = _engine.BuildSteps(prayer);
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal(20, decadeIndices.Count());
    }

    [Fact]
    public void BuildSteps_EachDecade_HasTenHailMarys()
    {
        var steps = _engine.BuildSteps(SpecificRosary());
        for (var d = 0; d < 5; d++)
        {
            var hailMarys = steps.Where(s => s.DecadeIndex == d && s.HailMaryIndexInDecade.HasValue).ToList();
            Assert.Equal(10, hailMarys.Count);
            Assert.Equal(Enumerable.Range(1, 10), hailMarys.Select(s => s.HailMaryIndexInDecade!.Value));
        }
    }

    [Fact]
    public void BuildSteps_IncludeApostlesCreedFalse_OmitsCreedStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeApostlesCreed = false,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.DoesNotContain(steps, s => s.Title == "Apostles' Creed");
    }

    [Fact]
    public void BuildSteps_IncludeApostlesCreedTrue_IncludesCreedStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeApostlesCreed = true,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Contains(steps, s => s.Title == "Apostles' Creed");
    }

    [Fact]
    public void BuildSteps_FinalSignOfCross_IsLastStepWhenIncluded()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeFinalSignOfCross = true,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void BuildSteps_FinalSignOfCross_OmittedWhenDisabled()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeFinalSignOfCross = false,
            MarianAntiphon = MarianAntiphonOption.None,
            IncludeStMichaelPrayer = false,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.NotEqual("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void AramaicSignOfCrossUsesPerRosaryFormUntilAramaicBecomesTheAppDefault()
    {
        var savedDefault = AppSettings.DefaultLanguageCode;
        var savedForm = AppSettings.AramaicSignOfCrossForm;
        try
        {
            AppSettings.SetDefaultLanguageCode("en");
            AppSettings.SetAramaicSignOfCrossForm(AppSettings.AramaicSignOfCrossFormB);

            var formA = _engine.BuildSteps(SpecificRosary(new RosaryOptions
            {
                MysterySelectionMode = MysterySelectionMode.Specific,
                SpecificMysteryGroup = MysteryGroup.Joyful,
                AramaicSignOfCrossForm = AppSettings.AramaicSignOfCrossFormA,
            }, "arc"));
            Assert.Equal(
                "בשמָא דַאבָא ✠ ודַברָא ודרוּחָא קַדִישָא, חַד אַלָהָא שַרִירָא. אַמִין.",
                formA[0].Body);
            Assert.Equal(
                "ܒܫܡܳܐ ܕܰܐܒܳܐ ✠ ܘܕܰܒܪܳܐ ܘܕܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ، ܚܰܕ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܐܰܡܺܝܢ.",
                formA[0].TransliteratedBody);
            Assert.Equal(formA[0].Body, formA[^1].Body);

            var formB = _engine.BuildSteps(SpecificRosary(new RosaryOptions
            {
                MysterySelectionMode = MysterySelectionMode.Specific,
                SpecificMysteryGroup = MysteryGroup.Joyful,
                AramaicSignOfCrossForm = AppSettings.AramaicSignOfCrossFormB,
            }, "arc"));
            Assert.Equal(
                "בשֶם אַבָא ✠ ובַרָא ורוּחָא קַדִישָא، חַד אַלָהָא שַרִירָא. אַמִין.",
                formB[0].Body);
            Assert.Equal(
                "ܒܫܶܡ ܐܰܒܳܐ ✠ ܘܒܰܪܳܐ ܘܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ، ܚܰܕ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܐܰܡܺܝܢ.",
                formB[0].TransliteratedBody);

            AppSettings.SetDefaultLanguageCode("arc");
            var systemWide = _engine.BuildSteps(SpecificRosary(new RosaryOptions
            {
                MysterySelectionMode = MysterySelectionMode.Specific,
                SpecificMysteryGroup = MysteryGroup.Joyful,
                AramaicSignOfCrossForm = AppSettings.AramaicSignOfCrossFormA,
            }, "arc"));
            Assert.Equal(formB[0].Body, systemWide[0].Body);
        }
        finally
        {
            AppSettings.SetDefaultLanguageCode(savedDefault);
            AppSettings.SetAramaicSignOfCrossForm(savedForm);
        }
    }

    [Fact]
    public void BuildSteps_EternalRestAfterEachDecade_AddsOneStepPerDecade()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            EternalRestForDeceased = EternalRestPlacement.AfterEachDecade,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Equal(5, steps.Count(s => s.Title == "For the Faithful Departed"));
    }

    [Fact]
    public void BuildSteps_EternalRestAtEndOnly_AddsExactlyOneStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            EternalRestForDeceased = EternalRestPlacement.AtEndOnly,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Single(steps.Where(s => s.Title == "For the Faithful Departed"));
    }

    [Fact]
    public void BuildSteps_MarianAntiphonNone_HasNoAntiphonStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            MarianAntiphon = MarianAntiphonOption.None,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.DoesNotContain(steps, s => s.IsAntiphon);
    }

    [Fact]
    public void BuildSteps_MarianAntiphonSalveRegina_AddsExactlyOneAntiphonStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            MarianAntiphon = MarianAntiphonOption.SalveRegina,
        });
        var steps = _engine.BuildSteps(prayer);
        var antiphonSteps = steps.Where(s => s.IsAntiphon).ToList();
        Assert.Single(antiphonSteps);
        Assert.Equal("Salve Regina", antiphonSteps[0].Title);
    }

    [Fact]
    public void ResolveMysteryGroups_Specific_ReturnsSingleChosenGroup()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Sorrowful,
        });
        Assert.Equal([MysteryGroup.Sorrowful], _engine.ResolveMysteryGroups(prayer));
    }

    [Fact]
    public void ResolveMysteryGroups_TwentyMystery_IsChronologicalOrder()
    {
        var prayer = SpecificRosary(new RosaryOptions { MysterySelectionMode = MysterySelectionMode.TwentyMystery });
        Assert.Equal(
            [MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
            _engine.ResolveMysteryGroups(prayer));
    }

    [Fact]
    public void ResolveMysteryGroups_SingleMystery_ReturnsOneGroup()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.SingleMystery,
            SpecificMysteryGroup = MysteryGroup.Sorrowful,
            SpecificMysteryOrder = 3,
        });
        Assert.Equal([MysteryGroup.Sorrowful], _engine.ResolveMysteryGroups(prayer));
    }

    [Fact]
    public void BuildSteps_SingleMystery_ProducesExactlyOneDecade()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.SingleMystery,
            SpecificMysteryGroup = MysteryGroup.Sorrowful,
            SpecificMysteryOrder = 3,
        });
        var steps = _engine.BuildSteps(prayer);
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal([0], decadeIndices);
    }

    [Fact]
    public void BuildSteps_SingleMystery_AnnouncesTheChosenMysteryNotTheFirst()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.SingleMystery,
            SpecificMysteryGroup = MysteryGroup.Sorrowful,
            SpecificMysteryOrder = 3,
        });
        var steps = _engine.BuildSteps(prayer);
        var announcement = steps.First(s => s.IsScripture);
        // 3rd Sorrowful Mystery is the Crowning with Thorns, not the 1st (Agony in the Garden).
        Assert.Equal("The Crowning with Thorns", announcement.Title);
        Assert.Equal("3rd Mystery", announcement.Subtitle);
    }

    [Fact]
    public void BuildSteps_PresenterModeOff_ReproducesExistingStepCount()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            PresenterMode = false,
        });
        Assert.Equal(79, _engine.BuildSteps(prayer).Count);
    }

    [Fact]
    public void BuildSteps_PresenterMode_CollapsesHailMaryAndGloryBeIntoOneStepPerDecade()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            PresenterMode = true,
        });
        var steps = _engine.BuildSteps(prayer);

        for (var d = 0; d < 5; d++)
        {
            var hailMarySteps = steps.Where(s => s.DecadeIndex == d && s.HailMaryIndexInDecade.HasValue).ToList();
            Assert.Single(hailMarySteps);
            Assert.Equal(10, hailMarySteps[0].HailMaryIndexInDecade);
            Assert.Equal("Hail Mary & Glory Be", hailMarySteps[0].Title);
        }
    }

    [Fact]
    public void BuildSteps_PresenterMode_CombinedStepBodyContainsBothPrayers()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            PresenterMode = true,
        });
        var steps = _engine.BuildSteps(prayer);
        var combined = steps.First(s => s.Title == "Hail Mary & Glory Be");
        Assert.Contains("Hail Mary,\nfull of grace", combined.Body);
        Assert.Contains("Glory be to the Father", combined.Body);
    }

    [Fact]
    public void BuildSteps_PresenterMode_StillIncludesFatimaPrayerPerDecade()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeFatimaPrayer = true,
            PresenterMode = true,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Equal(5, steps.Count(s => s.Title == "Fatima Prayer"));
    }

    [Fact]
    public void BuildSteps_PresenterMode_KeepsAnnouncementAndOurFatherAsSeparateSteps()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            PresenterMode = true,
        });
        var steps = _engine.BuildSteps(prayer);
        var decadeZeroSteps = steps.Where(s => s.DecadeIndex == 0).ToList();
        // Announcement, Our Father, Hail Mary & Glory Be, Fatima Prayer = 4 (default config includes Fatima).
        Assert.Equal(4, decadeZeroSteps.Count);
        Assert.True(decadeZeroSteps[0].IsScripture);
        Assert.Equal("Our Father", decadeZeroSteps[1].Title);
        Assert.Equal("Hail Mary & Glory Be", decadeZeroSteps[2].Title);
    }

    [Theory]
    [InlineData(false, false, false, 0)]
    [InlineData(true, false, false, 4)]
    [InlineData(false, true, false, 4)]
    [InlineData(false, false, true, 5)]
    [InlineData(true, true, false, 8)]
    [InlineData(true, false, true, 9)]
    [InlineData(false, true, true, 9)]
    [InlineData(true, true, true, 13)]
    public void ClosingGroupsHaveIndependentIntroductionsAndPrayers(bool pope, bool bishop, bool departed, int added)
    {
        var baseline = new RosaryOptions { MysterySelectionMode = MysterySelectionMode.Specific };
        var original = _engine.BuildSteps(SpecificRosary(baseline));
        var changed = _engine.BuildSteps(SpecificRosary(baseline with
        {
            IncludeClosingPopeIntention = pope,
            IncludeClosingBishopIntention = bishop,
            IncludeClosingDepartedIntention = departed,
        }));
        Assert.Equal(original.Count + added, changed.Count);
        Assert.Equal(pope ? 1 : 0, changed.Count(step => step.Title == "Closing prayers for the Pope"));
        Assert.Equal(bishop ? 1 : 0, changed.Count(step => step.Title == "Closing prayers for the bishop"));
        Assert.Equal(departed ? 1 : 0, changed.Count(step => step.Title == "Closing prayers for the faithful departed"));
    }

    [Fact]
    public void BuildSteps_ClosingIntentions_AddThirteenSteps()
    {
        var withoutIntentions = _engine.BuildSteps(SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeClosingIntentions = false,
        }));
        var withIntentions = _engine.BuildSteps(SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeClosingIntentions = true,
        }));

        // Each intention has one introduction, then Our Father/Hail Mary/Glory Be;
        // the departed group also ends with "Requiescant in pace".
        Assert.Equal(withoutIntentions.Count + 13, withIntentions.Count);
    }

    [Fact]
    public void BuildSteps_ClosingIntentions_FollowTheAntiphonDirectly()
    {
        var prayer = new Prayer
        {
            Kind = PrayerKind.Rosary,
            LanguageCode = "la",
            Rosary = new RosaryOptions
            {
                MysterySelectionMode = MysterySelectionMode.Specific,
                SpecificMysteryGroup = MysteryGroup.Joyful,
                IncludeClosingIntentions = true,
            },
        };
        var steps = _engine.BuildSteps(prayer).ToList();

        var antiphonIndex = steps.FindIndex(s => s.IsAntiphon);
        Assert.True(antiphonIndex >= 0);
        Assert.Equal("Pro intentionibus Summi Pontificis", steps[antiphonIndex + 1].Title);
        Assert.Equal(
            "Pro intentionibus Summi Pontificis et necessitatibus Ecclesiae et patriae.",
            steps[antiphonIndex + 1].Body);
        Assert.Equal("Pater Noster", steps[antiphonIndex + 2].Title);
        Assert.Null(steps[antiphonIndex + 2].Subtitle);
        Assert.Equal("Requiescant in pace.\n**Amen.**", steps[antiphonIndex + 13].Body);
    }

    /// <summary>The local ordinary the second intention prays for is the Patriarch in the
    /// Vicariate's Hebrew and the Exarch in the Mission's rite — the he-x-gamliel overlay swaps
    /// that introduction's body while preserving its vowel points.</summary>
    [Fact]
    public void BuildSteps_ClosingIntentions_PatriarchInHebrewExarchInGamlielRite()
    {
        Prayer RosaryIn(string languageCode) => new()
        {
            Kind = PrayerKind.Rosary,
            LanguageCode = languageCode,
            Rosary = new RosaryOptions
            {
                MysterySelectionMode = MysterySelectionMode.Specific,
                SpecificMysteryGroup = MysteryGroup.Joyful,
                IncludeClosingIntentions = true,
            },
        };

        var hebrew = _engine.BuildSteps(RosaryIn("he"));
        Assert.Contains(hebrew, s => HebrewDisplayText.WithoutMarks(s.Body).Contains("הפטריארך"));

        var gamliel = _engine.BuildSteps(RosaryIn("he-x-gamliel"));
        Assert.Contains(gamliel, s => HebrewDisplayText.WithoutMarks(s.Body).Contains("ההגמון"));
        Assert.DoesNotContain(gamliel, s => HebrewDisplayText.WithoutMarks(s.Body).Contains("הפטריארך"));
    }

    [Fact]
    public void BuildSteps_EasternImageStyle_SwapsOnlyMysteryImagery()
    {
        var classic = _engine.BuildSteps(SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            MysteryImageStyle = MysteryImageStyle.Classic,
        }));
        var eastern = _engine.BuildSteps(SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            MysteryImageStyle = MysteryImageStyle.Eastern,
        }));

        Assert.Equal(classic.Count, eastern.Count);
        Assert.All(classic, s => Assert.Null(s.ImageVariantKey));
        for (var i = 0; i < eastern.Count; i++)
        {
            if (eastern[i].Mystery is { } mystery)
            {
                Assert.Equal($"eastern_{mystery.ImageKey}", eastern[i].ImageVariantKey);
            }
            else
            {
                Assert.Null(eastern[i].ImageVariantKey);
            }
        }
    }

    [Fact]
    public void BuildSteps_EasternImageStyle_AppliesToPresenterCombinedStep()
    {
        var steps = _engine.BuildSteps(SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            PresenterMode = true,
            MysteryImageStyle = MysteryImageStyle.Eastern,
        }));

        var combined = steps.Where(s => s.HailMaryIndexInDecade == 10).ToList();
        Assert.Equal(5, combined.Count);
        Assert.All(combined, s => Assert.StartsWith("eastern_", s.ImageVariantKey));
    }

    [Fact]
    public void BuildSteps_OpeningFatimaPrayer_FollowsTheThreeOpeningHailMarys()
    {
        var steps = _engine.BuildSteps(SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeOpeningPrayers = true,
            IncludeOpeningFatimaPrayer = true,
            IncludeFatimaPrayer = false,
        })).ToList();

        var fatimaIndex = steps.FindIndex(step => step.Title == "Fatima Prayer");
        Assert.True(fatimaIndex > 0);
        Assert.Equal("Hail Mary (3 of 3)", steps[fatimaIndex - 1].Title);
        Assert.Equal("Glory Be", steps[fatimaIndex + 1].Title);
        Assert.Single(steps.Where(step => step.Title == "Fatima Prayer"));
    }

    [Fact]
    public void BuildSteps_OpeningVirtueHailMarysCarryLocalizedCounters()
    {
        var english = _engine.BuildSteps(SpecificRosary(languageCode: "en"));
        Assert.Equal(
            ["Hail Mary (1 of 3)", "Hail Mary (2 of 3)", "Hail Mary (3 of 3)"],
            english.Where(step => step.ImageOverrideKey?.StartsWith("virtue_") == true)
                .Select(step => step.Title));

        var hebrew = _engine.BuildSteps(SpecificRosary(languageCode: "he"));
        var opening = hebrew.Where(step => step.ImageOverrideKey?.StartsWith("virtue_") == true)
            .ToList();
        Assert.Equal(
            ["שמחי מרים (1 מתוך 3)", "שמחי מרים (2 מתוך 3)", "שמחי מרים (3 מתוך 3)"],
            opening.Select(step => step.Title));
        Assert.All(opening, step => Assert.Contains('\u05B0', step.Body));
        var aramaic = _engine.BuildSteps(SpecificRosary(languageCode: "arc"))
            .Where(step => step.ImageOverrideKey?.StartsWith("virtue_") == true).ToList();
        Assert.Equal(3, aramaic.Count);
        Assert.EndsWith("(1 מן 3)", aramaic[0].Title);
        Assert.EndsWith("(1 ܡܶܢ 3)", PrayerTranslations.FlowTitle(aramaic[0].Title, "arc", true));
        Assert.Equal("1 מֶן 75", PrayerTranslations.AramaicProgress(1, 75, "arc", false));
        Assert.Equal("1 ܡܶܢ 75", PrayerTranslations.AramaicProgress(1, 75, "arc", true));
        Assert.Null(PrayerTranslations.AramaicProgress(1, 75, "en", true));
    }

    [Fact]
    public void AramaicScriptPreferenceFindsTheRequestedWritingSystem()
    {
        foreach (var script in new[] { "Hebr", "Syrc" })
        {
            Assert.Equal(script == "Syrc", PrayerTranslations.InitialTransliteration("arc", "שלם", "ܫܠܡ", script));
            Assert.Equal(script == "Hebr", PrayerTranslations.InitialTransliteration("arc", "ܫܠܡ", "שלם", script));
        }
        Assert.False(PrayerTranslations.InitialTransliteration("arc", "שלם", null, "Syrc"));
        Assert.Null(PrayerTranslations.InitialTransliteration("he", "שלום", "Shalom", "Syrc"));
        var saved = AppSettings.AramaicDefaultScript;
        try
        {
            AppSettings.SetAramaicDefaultScript("Syrc");
            Assert.Equal("Syrc", AppSettings.AramaicDefaultScript);
            AppSettings.SetAramaicDefaultScript("invalid");
            Assert.Equal("Hebr", AppSettings.AramaicDefaultScript);
        }
        finally { AppSettings.SetAramaicDefaultScript(saved); }
    }

    /// <summary>The Aramaic Rosary's bundle deliberately contributes only the Peshitta
    /// Scripture for each mystery. Its ordinary title and fruit therefore continue through
    /// the configured language fallback chain, while the Syriac-script rendering remains
    /// paired with the Hebrew-square description that supplied it.</summary>
    [Fact]
    public void BuildSteps_AramaicMysteryUsesPeshittaAndItsSyriacTransliteration()
    {
        var original = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder(["en", "la"]);

            const string key = "joyful_01_annunciation";
            var english = MysteryTranslations.Get("en", key);
            var hebrew = MysteryTranslations.Get("he", key);
            var aramaic = MysteryTranslations.Get("arc", key);

            Assert.Equal(english.Title, aramaic.Title);
            Assert.Equal(english.Fruit, aramaic.Fruit);
            Assert.EndsWith("— לוּקָס א׳ 26–38 (דליטש)", hebrew.Description);
            Assert.DoesNotContain("לוּקָס א׳:", hebrew.Description);
            Assert.StartsWith("בירחא דין דשתא", aramaic.Description);
            Assert.EndsWith("— לוקא א׳ 26–38 (פשיטתא)", aramaic.Description);
            Assert.DoesNotContain("לוקא א׳:", aramaic.Description);
            Assert.StartsWith("ܒܝܪܚܐ ܕܝܢ ܕܫܬܐ", aramaic.TransliteratedDescription);

            var announcement = _engine.BuildSteps(SpecificRosary(languageCode: "arc"))
                .First(step => step.Mystery?.ImageKey == key);
            Assert.Equal(english.Title, announcement.Title);
            Assert.StartsWith(aramaic.Description, announcement.Body);
            Assert.NotNull(announcement.TransliteratedBody);
            Assert.StartsWith(aramaic.TransliteratedDescription!, announcement.TransliteratedBody!);

            Assert.EndsWith($"\n\n{PrayerTranslations.Get("arc", PrayerKey.FructusMysteriiLabel)}: {aramaic.Fruit}", announcement.Body);
            Assert.EndsWith($"\n\n{PrayerPackStore.Transliteration("rosary", "arc", "fructusMysteriiLabel")}: {aramaic.Fruit}", announcement.TransliteratedBody!);
        }
        finally
        {
            AppSettings.SetLanguageFallbackOrder(original);
        }
    }

    [Fact]
    public void EveryEasternMysteryImageShipsInTheRosaryPack()
    {
        Assert.All(MysteryCatalog.All, m => Assert.NotNull(PrayerPackStore.ImageData($"eastern_{m.ImageKey}")));
    }
}
