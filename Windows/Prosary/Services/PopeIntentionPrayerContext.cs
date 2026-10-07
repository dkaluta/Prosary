using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

public sealed record PopeIntentionPrayerPublication(string LanguageCode, string Title, string Text, string? TranslationCredit);

public static class PopeIntentionPrayerContext
{
    public static PopeIntentionPrayerPublication? Resolve(RosaryStep step, PopeIntention? intention,
        string language, bool isEnabled = false)
    {
        if (!isEnabled || step.PrayerKey != "intentioPontificis" || intention is null) return null;
        var requested = UiLanguageCatalog.Normalize(language);
        var complete = !string.IsNullOrWhiteSpace(UiLanguageCatalog.Localized(intention.TitleByLanguage, requested))
            && !string.IsNullOrWhiteSpace(UiLanguageCatalog.Localized(intention.TextByLanguage, requested));
        var code = complete ? requested : "en";
        return new(code, intention.LocalizedTitle(code), intention.LocalizedText(code),
            UiLanguageCatalog.Localized(intention.TranslationCreditByLanguage, code));
    }

    public static string AppendPublishedIntention(string body, RosaryStep step, string language)
    {
        var publication = Resolve(step, TodayInfoStore.Intention(DateOnly.FromDateTime(DateTime.Now)),
            language, AppSettings.ShowPopeIntentionInPrayers);
        if (publication is null) return body;
        return string.Join("\n\n", new[] { body, publication.Title, publication.Text,
            Loc.Tr("prayer_pope_intention_source", "Pope’s Worldwide Prayer Network"), publication.TranslationCredit }
            .Where(text => !string.IsNullOrEmpty(text)));
    }
}
