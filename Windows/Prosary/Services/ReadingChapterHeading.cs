using System.Globalization;
using System.Text;
using Prosary.Localization;

namespace Prosary.Services;

/// <summary>Chapter headings belong to the Bible edition, independently of the interface.</summary>
public static class ReadingChapterHeading
{
    public static string Label(string language, string script = "Hebr")
    {
        var code = LanguageCode(language);
        // These source-language labels are outside the eight interface locales. The Aramaic
        // chapter term is attested by CAL and the Antioch Bible (see Shared architecture).
        if (code == "arc") return script == "Syrc" ? "ܩܦܠܐܘܢ" : "קפלאון";
        if (code == "el") return "Κεφάλαιο";
        var fallback = code switch
        {
            "he" => "פרק", "ar" => "الإصحاح", "ru" => "Глава", "uk" => "Розділ",
            "tl" => "Kabanata", "fr" => "Chapitre", "it" => "Capitolo", _ => "Chapter",
        };
        return Loc.Tr("readings_chapter", fallback, code);
    }

    public static string Number(int chapter, string language, string script = "Hebr")
    {
        var code = LanguageCode(language);
        var decimalNumber = chapter.ToString(CultureInfo.InvariantCulture);
        if (code == "ar") return string.Concat(decimalNumber.Select(c => c is >= '0' and <= '9' ? (char)('٠' + c - '0') : c));
        if (chapter is <= 0 or >= 1000) return decimalNumber;
        if (code == "he" || code == "arc" && script != "Syrc") return LetterNumber(chapter, false);
        if (code == "arc") return LetterNumber(chapter, true);
        return decimalNumber;
    }

    private static string LanguageCode(string language) => language.Trim().Replace('_', '-').Split('-')[0].ToLowerInvariant() switch
    {
        "iw" => "he", "fil" => "tl", "grc" => "el", var code => code,
    };

    private static string LetterNumber(int number, bool syriac)
    {
        var result = new StringBuilder();
        var letters = syriac ? "ܬܫܪܩܨܦܥܣܢܡܠܟܝܛܚܙܘܗܕܓܒܐ" : "תשרקצפעסנמלכיטחזוהדגבא";
        int[] values = [400, 300, 200, 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1];
        for (var index = 0; index < values.Length; index++)
        {
            // Hebrew avoids the divine-name forms for 15/16, including 115/116.
            if (!syriac && number is 15 or 16)
            {
                result.Append(number == 15 ? "טו" : "טז");
                break;
            }
            while (number >= values[index])
            {
                result.Append(letters[index]);
                number -= values[index];
            }
        }
        if (!syriac)
        {
            if (result.Length == 1) result.Append('׳');
            else result.Insert(result.Length - 1, '״');
        }
        return result.ToString();
    }
}
