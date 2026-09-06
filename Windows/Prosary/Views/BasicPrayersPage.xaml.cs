using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Localization;
using Prosary.Models;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>The basic prayers on their own, outside any devotion (Erez, 2026-08-07) — each row
/// opens its prayer as a single step in the shared flow chrome.</summary>
public sealed partial class BasicPrayersPage : Page
{
    public BasicPrayersViewModel ViewModel { get; }

    public BasicPrayersPage()
    {
        ViewModel = App.Services.GetRequiredService<BasicPrayersViewModel>();
        InitializeComponent();
        var languageLabel = Loc.Tr("EdLanguageHeader/Text", "Prayer language");
        AutomationProperties.SetName(LanguageMenuButton, languageLabel);
        ToolTipService.SetToolTip(LanguageMenuButton, languageLabel);
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.Load();
        BuildLanguageFlyout();
    }

    private void BuildLanguageFlyout() =>
        Prosary.Controls.PrayerLanguageMenu.Populate(LanguageFlyout, ViewModel.Languages,
            ViewModel.CurrentLanguageRaw, raw =>
        {
            ViewModel.SelectLanguage(raw);
            BuildLanguageFlyout();
            return Task.CompletedTask;
        });

    /// <summary>The approved reorder pattern (not jiggle), the same dialog HomePage uses: a
    /// ListView with built-in drag-reorder; Done persists the new sequence, Reset returns to
    /// catalog order.</summary>
    private async void OnEditOrder(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        var working = new System.Collections.ObjectModel.ObservableCollection<BasicPrayerRow>(ViewModel.Rows);
        var list = new ListView
        {
            ItemsSource = working,
            CanReorderItems = true,
            CanDragItems = true,
            AllowDrop = true,
            SelectionMode = ListViewSelectionMode.None,
            DisplayMemberPath = "Title",
        };
        var dialog = new ContentDialog
        {
            Title = Prosary.Localization.Loc.Tr("prayer_order_title", "Prayer order"),
            Content = list,
            PrimaryButtonText = Prosary.Localization.Loc.Tr("common_done", "Done"),
            SecondaryButtonText = Prosary.Localization.Loc.Tr("common_reset", "Reset"),
            CloseButtonText = Prosary.Localization.Loc.Tr("common_cancel", "Cancel"),
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        var result = await dialog.ShowAsync();
        if (result == ContentDialogResult.Primary)
        {
            ViewModel.CommitOrder(working.Select(r => r.Id));
        }
        else if (result == ContentDialogResult.Secondary)
        {
            ViewModel.ResetOrder();
        }
    }
}
