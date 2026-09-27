using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class ReadingChapterHeadingTests
{
    [Theory]
    [InlineData(1, "א׳")]
    [InlineData(9, "ט׳")]
    [InlineData(10, "י׳")]
    [InlineData(11, "י״א")]
    [InlineData(15, "ט״ו")]
    [InlineData(16, "ט״ז")]
    [InlineData(20, "כ׳")]
    [InlineData(100, "ק׳")]
    [InlineData(115, "קט״ו")]
    [InlineData(116, "קט״ז")]
    [InlineData(119, "קי״ט")]
    [InlineData(150, "ק״נ")]
    public void HebrewChaptersUseGematriaAndConventionalPunctuation(int chapter, string expected)
    {
        Assert.Equal(expected, ReadingChapterHeading.Number(chapter, "he"));
        Assert.Equal(expected, ReadingChapterHeading.Number(chapter, "iw-IL"));
        Assert.Equal(expected, ReadingChapterHeading.Number(chapter, "arc", "Hebr"));
    }

    [Theory]
    [InlineData(1, "ܐ")]
    [InlineData(15, "ܝܗ")]
    [InlineData(16, "ܝܘ")]
    [InlineData(115, "ܩܝܗ")]
    [InlineData(150, "ܩܢ")]
    public void SyriacChaptersUseSyriacLettersWithoutHebrewPunctuation(int chapter, string expected) =>
        Assert.Equal(expected, ReadingChapterHeading.Number(chapter, "arc", "Syrc"));

    [Theory]
    [InlineData("ar", "١١٥")]
    [InlineData("ar-LB", "١١٥")]
    [InlineData("en", "115")]
    [InlineData("ru", "115")]
    [InlineData("tl", "115")]
    [InlineData("fil", "115")]
    [InlineData("fr", "115")]
    [InlineData("it", "115")]
    [InlineData("uk", "115")]
    [InlineData("el", "115")]
    [InlineData("grc", "115")]
    public void OtherBibleLanguagesUseTheirDecimalNumerals(string language, string expected) =>
        Assert.Equal(expected, ReadingChapterHeading.Number(115, language));
}
