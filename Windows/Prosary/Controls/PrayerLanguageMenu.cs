using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Controls;

/// <summary>All prayer flows show one language row and a separate Hebrew tradition submenu.</summary>
public static class PrayerLanguageMenu
{
    public static void Populate(MenuFlyout menu, IEnumerable<LanguageOption> languages,
        string current, Func<string, Task> select)
    {
        menu.Items.Clear();
        var choices = new[] { new LanguageOption("", Loc.Tr("flow_app_setting", "App setting"), false) }
            .Concat(languages);
        foreach (var language in choices)
        {
            var item = new ToggleMenuFlyoutItem
            {
                Text = language.NativeName,
                IsChecked = LanguageCatalog.PickerLanguageCode(current) == language.Code,
            };
            item.Click += async (_, _) => await select(LanguageCatalog.SelectingLanguage(language.Code, current));
            menu.Items.Add(item);
        }
        var resolved = LanguageCatalog.Resolve(current).Code;
        if (LanguageCatalog.PickerLanguageCode(resolved) != "he") return;
        var tradition = new MenuFlyoutSubItem { Text = Loc.Tr("prayer_tradition", "Prayer tradition") };
        foreach (var rite in LanguageCatalog.Rites(resolved))
        {
            var item = new ToggleMenuFlyoutItem { Text = rite.NativeName, IsChecked = resolved == rite.Code };
            item.Click += async (_, _) => await select(rite.Code);
            tradition.Items.Add(item);
        }
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(tradition);
    }
}
