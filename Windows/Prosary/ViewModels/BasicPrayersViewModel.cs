using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Services;
using Windows.UI;

namespace Prosary.ViewModels;

/// <summary>One row of the basic-prayers list — the title resolved in the prayer language
/// through the same chains the flows use, so the list itself reads in the rite being
/// prayed.</summary>
public sealed record BasicPrayerRow(string Id, string Title, string ImageFile, bool IsFavorite)
{
    public string FavoriteGlyph => IsFavorite ? "★" : "☆";
}

/// <summary>The basic prayers on their own, outside any devotion (Erez, 2026-08-07). Mirrors
/// iOS's BasicPrayersView / Android's BasicPrayersScreen.</summary>
public partial class BasicPrayersViewModel : ObservableObject
{
    [ObservableProperty]
    private IReadOnlyList<BasicPrayerRow> _rows = [];

    [ObservableProperty]
    private bool _isRightToLeft;

    public void Load()
    {
        var language = LanguageCatalog.Resolve(null);
        IsRightToLeft = language.IsRightToLeft;
        // Reorderable per Erez (2026-08-08): the HomeOrder pattern — persisted ids first,
        // catalog order for the rest.
        Rows = BasicPrayersOrder.ApplyFavorites(BasicPrayersOrder.Apply(BasicPrayerCatalog.All))
            .Select(p => new BasicPrayerRow(
                p.Id,
                PrayerPackStore.ResolveDisplayText(p.BundleId, language.Code, p.TitleKey),
                ImageFile(p.ImageKey),
                AppSettings.FavoriteBasicPrayerIds.Contains(p.Id)))
            .ToList();
    }

    /// <summary>Called by the page's reorder dialog after a drag-drop: persists the ListView's
    /// new sequence and re-derives the rows.</summary>
    public void CommitOrder(IEnumerable<string> ids)
    {
        BasicPrayersOrder.Save(ids);
        Load();
    }

    public void ResetOrder()
    {
        BasicPrayersOrder.Reset();
        Load();
    }

    [RelayCommand]
    private void Open(BasicPrayerRow row) => Router.Navigate<Views.BasicPrayerFlowPage>(row.Id);

    [RelayCommand]
    private void ToggleFavorite(BasicPrayerRow row)
    {
        AppSettings.ToggleFavoriteBasicPrayer(row.Id);
        Load();
    }

    internal static string ImageFile(string imageKey) =>
        PrayerPackStore.ImageFileUri(imageKey) ?? (imageKey == "cross_placeholder"
            ? "ms-appx:///Assets/Images/cross_placeholder.png"
            : $"ms-appx:///Assets/Images/{imageKey}.jpg");
}

/// <summary>One basic prayer as a bounded single-step flow: the same
/// <see cref="Prosary.Controls.PrayerStepFlowControl"/> chrome every devotion uses, with
/// "Finish" as its only footer action.</summary>
public partial class BasicPrayerViewModel : ObservableObject, IPrayerStepFlowViewModel
{
    [ObservableProperty]
    private string _header = string.Empty;

    [ObservableProperty]
    private string _body = string.Empty;

    [ObservableProperty]
    private string _mysteryImageFile = "ms-appx:///Assets/Images/cross_placeholder.png";

    [ObservableProperty]
    private string _progressText = string.Empty;

    [ObservableProperty]
    private bool _isRightToLeft;

    [ObservableProperty]
    private string _bodyFontFamily = "Cambria";

    [ObservableProperty]
    private double _bodyFontSize = 18;

    public string? Subtitle => null;

    public bool HasSubtitle => false;

    public double? Progress => 1.0;

    public Color SeasonColor => Colors.Transparent;

    public bool CanGoBack => false;

    public string NextButtonText => Loc.Tr("common_finish", "Finish");

    public bool IsLastStep => true;

    public void Load(string prayerId)
    {
        if (BasicPrayerCatalog.Prayer(prayerId) is not { } prayer) return;
        var language = LanguageCatalog.Resolve(null);
        Header = PrayerPackStore.ResolveDisplayText(prayer.BundleId, language.Code, prayer.TitleKey);
        Body = PrayerPackStore.ResolveBodyText(prayer.BundleId, language.Code, prayer.BodyKey);
        MysteryImageFile = BasicPrayersViewModel.ImageFile(prayer.ImageKey);
        ProgressText = string.Format(Loc.Tr("flow_step_of", "{0} of {1}"), 1, 1);
        IsRightToLeft = language.IsRightToLeft;
        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(language.Code, isScripture: false);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(language.Code, isScripture: false);
    }

    [RelayCommand]
    private void Next() => Router.GoBack();

    [RelayCommand]
    private void Back()
    {
    }
}
