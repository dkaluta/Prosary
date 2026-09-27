using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Controls;

/// <summary>Prayer flows offer a Hebrew tradition submenu only for their authored alternatives.</summary>
public static class PrayerLanguageMenu
{
    public static void Populate(MenuFlyout menu, IEnumerable<LanguageOption> languages,
        string current, Func<string, Task> select, IReadOnlyList<LanguageOption>? hebrewRites = null)
    {
        menu.Items.Clear();
        var rites = hebrewRites ?? LanguageCatalog.Rites("he");
        var choices = new[] { new LanguageOption("", string.Format(
            Loc.Tr("language_default_parenthesized", "Default ({0})"),
            LanguageCatalog.Resolve("").NativeName), false) }
            .Concat(languages);
        foreach (var language in choices)
        {
            var item = new ToggleMenuFlyoutItem
            {
                Text = language.NativeName,
                IsChecked = LanguageCatalog.PickerLanguageCode(current) == language.Code,
            };
            item.Click += async (_, _) => await select(language.Code == "he" && rites.Count == 1
                ? rites[0].Code : LanguageCatalog.SelectingLanguage(language.Code, current));
            menu.Items.Add(item);
        }
        var resolved = LanguageCatalog.Resolve(current).Code;
        if (LanguageCatalog.PickerLanguageCode(resolved) != "he" || rites.Count <= 1) return;
        var tradition = new MenuFlyoutSubItem { Text = Loc.Tr("prayer_tradition", "Prayer tradition") };
        foreach (var rite in rites)
        {
            var item = new ToggleMenuFlyoutItem { Text = rite.NativeName, IsChecked = resolved == rite.Code };
            item.Click += async (_, _) => await select(rite.Code);
            tradition.Items.Add(item);
        }
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(tradition);
    }
}
