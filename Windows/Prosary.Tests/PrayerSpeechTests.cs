using System.Text.Json;
using Prosary.Localization;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class PrayerSpeechTests
{
    [Theory]
    [InlineData("en-GB", "en", true)]
    [InlineData("he-IL", "he-x-gamliel", true)]
    [InlineData("iw-IL", "he", true)]
    [InlineData("fil-PH", "tl", true)]
    [InlineData("en-US", "la", false)]
    [InlineData("he-IL", "arc", false)]
    [InlineData("en-US", "", false)]
    public void VoiceMustMatchPrayerLanguage(string voice, string prayer, bool expected) =>
        Assert.Equal(expected, PrayerSpeechService.VoiceMatches(voice, prayer));

    [Fact]
    public void SpeechRemovesOnlyResponseWeightMarkers() =>
        Assert.Equal("Leader.\nResponse.", PrayerSpeechService.SpokenText("\nLeader.\n**Response.**\n"));

    [Fact]
    public void OlderAudioStaysNarrationAndMusicHasAnExplicitRole()
    {
        var json = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        var legacy = JsonSerializer.Deserialize<DevotionAudioTrack>("""{"id":"en","language":"en","file":"audio/en.opus","chapters":[{"start":0,"title":"Opening","stepIndex":0}]}""", json)!;
        Assert.True(legacy.IsNarration);
        var music = JsonSerializer.Deserialize<DevotionAudioTrack>("""{"id":"song","language":"en","file":"audio/song.opus","role":"music","chapters":[{"start":0,"title":"Opening song"}]}""", json)!;
        Assert.True(music.IsMusic);
        Assert.False(music.IsNarration);
        Assert.Null(music.Chapters![0].StepIndex);
    }

    [Fact]
    public void HebrewDivineNamesAreSpokenAsAdonaiOrElohim()
    {
        Assert.Equal("אֲדֹנָי לְעֶזְרָתִי חוּשָׁה", PrayerSpeechService.SpokenText("ה׳ לְעֶזְרָתִי חוּשָׁה", "he"));
        Assert.Equal("שִׁפְחַת אֲדֹנָי", PrayerSpeechService.SpokenText("שִׁפְחַת ה׳", "he"));
        Assert.Equal("הִנֵּה יָמִים בָּאִים נְאֻם־אֲדֹנָי", PrayerSpeechService.SpokenText("הִנֵּה יָמִים בָּאִים נְאֻם־יהוה", "he"));
        Assert.Equal("כֹּה אָמַר אֲדֹנָי אֱלֹהִים", PrayerSpeechService.SpokenText("כֹּה אָמַר אֲדֹנָי יהוה", "he"));
        Assert.Equal("אדני אֱלֹהִים", PrayerSpeechService.SpokenText("אדני יהוה", "he"));
        Assert.Equal("אֲדֹנָי וֵאלֹהִים", PrayerSpeechService.SpokenText("אֲדֹנָי וַיהוה", "he"));
        Assert.Equal("לַאדֹנָי הָאָרֶץ", PrayerSpeechService.SpokenText("לַיהוה הָאָרֶץ", "he"));
        Assert.Equal("בַּאדֹנָי חָסִיתִי", PrayerSpeechService.SpokenText("בַּיהוה חָסִיתִי", "he"));
        Assert.Equal("וַאדֹנָי צִוָּה", PrayerSpeechService.SpokenText("וַיהוה צִוָּה", "he"));
        Assert.Equal("מֵאדֹנָי", PrayerSpeechService.SpokenText("מֵיהוה", "he"));
        Assert.Equal("לַאדֹנָי", PrayerSpeechService.SpokenText("לַה׳", "he"));
        Assert.Equal("אֲדֹנָי", PrayerSpeechService.SpokenText("יי", "he"));
        Assert.Equal("וַאדֹנָי", PrayerSpeechService.SpokenText("וַיי", "he"));
        Assert.Equal("הוֹדוּ לַאדֹנָי כִּי־טוֹב", PrayerSpeechService.SpokenText("הוֹדוּ לַיהוָה כִּי־טוֹב", "he"));
    }
}
