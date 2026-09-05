using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;
using Prosary.Localization;

namespace Prosary.Views;

public sealed partial class HomePage : Page
{
    public HomeViewModel ViewModel { get; }

    public HomePage()
    {
        ViewModel = App.Services.GetRequiredService<HomeViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        await ViewModel.LoadAsync();
    }

    private void OnTodayLanguageMenuOpening(object sender, object e)
    {
        if (sender is not MenuFlyout menu) return;
        menu.Items.Clear();
        var choices = new[] { (Code: string.Empty, Name: Loc.Tr("today_language_app", "App language")) }
            .Concat(UiLanguageCatalog.All.Select(language => (Code: language.Code, Name: language.NativeName)));
        foreach (var (code, name) in choices)
        {
            var item = new ToggleMenuFlyoutItem { Text = name, IsChecked = ViewModel.TodayLanguageCode == code };
            item.Click += (_, _) => ViewModel.TodayLanguageCode = code;
            menu.Items.Add(item);
        }
    }

    /// <summary>The approved reorder pattern (not jiggle): a ListView with built-in
    /// drag-reorder inside a dialog; Done persists the new sequence, Reset returns to
    /// directory order at next launch.</summary>
    private void OnOpenBasicPrayers(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) =>
        Prosary.Navigation.Router.Navigate<BasicPrayersPage>();

    private async void OnEditOrder(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        var working = new System.Collections.ObjectModel.ObservableCollection<Prosary.ViewModels.DevotionCardModel>(ViewModel.DevotionCards);
        var list = new Microsoft.UI.Xaml.Controls.ListView
        {
            ItemsSource = working,
            CanReorderItems = true,
            CanDragItems = true,
            AllowDrop = true,
            SelectionMode = Microsoft.UI.Xaml.Controls.ListViewSelectionMode.None,
            DisplayMemberPath = "Title",
        };
        var dialog = new Microsoft.UI.Xaml.Controls.ContentDialog
        {
            Title = Loc.Tr("home_order_title", "Home order"),
            Content = list,
            PrimaryButtonText = Loc.Tr("common_done", "Done"),
            SecondaryButtonText = Loc.Tr("common_reset", "Reset"),
            CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
            DefaultButton = Microsoft.UI.Xaml.Controls.ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        var result = await dialog.ShowAsync();
        if (result == Microsoft.UI.Xaml.Controls.ContentDialogResult.Primary)
        {
            ViewModel.CommitOrder(working.Select(c => c.Id));
        }
        else if (result == Microsoft.UI.Xaml.Controls.ContentDialogResult.Secondary)
        {
            ViewModel.ResetOrder();
        }
    }
}
