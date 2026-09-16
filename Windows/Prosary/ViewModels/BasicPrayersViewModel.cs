using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Services;
using Windows.UI;

namespace Prosary.ViewModels;

/// <summary>One basic-prayer card with an optional, distinct interface-language subtitle.</summary>
public sealed record BasicPrayerRow(string Id, string Title, string ImageFile, bool IsPinned, string InterfaceSubtitle = "")
{
    public bool HasInterfaceSubtitle => !string.IsNullOrWhiteSpace(InterfaceSubtitle);
    public bool IsTitleRightToLeft => PrayerTypography.IsRightToLeft(PrayerTypography.ScriptOf(Title));
    public bool IsInterfaceSubtitleRightToLeft => PrayerTypography.IsRightToLeft(PrayerTypography.ScriptOf(InterfaceSubtitle));
    public string PinActionLabel => IsPinned ? Loc.Tr("basic_unpin", "Remove from Pray") : Loc.Tr("basic_pin", "Pin to Pray");
    public string PinGlyph => IsPinned ? "\uE77A" : "\uE718";
    public string PinAutomationId => $"basicPrayerPin-{Id}";
}

/// <summary>The basic prayers on their own, outside any devotion (Erez, 2026-08-07). Mirrors
/// iOS's BasicPrayersView / Android's BasicPrayersScreen.</summary>
public partial class BasicPrayersViewModel : ObservableObject
{
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;

    [ObservableProperty]
    private IReadOnlyList<BasicPrayerRow> _rows = [];

    [ObservableProperty]
    private bool _isRightToLeft;

    public string CurrentLanguageRaw => AppSettings.BasicPrayersLanguageCode;

    public IReadOnlyList<LanguageOption> Languages => LanguageCatalog.PickerOptions;

    public void SelectLanguage(string code)
    {
        AppSettings.SetBasicPrayersLanguageCode(code);
        Load();
    }

    public void Load()
    {
        var language = LanguageCatalog.Resolve(CurrentLanguageRaw);
        IsRightToLeft = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current);
        // Reorderable per Erez (2026-08-08): the HomeOrder pattern — persisted ids first,
        // catalog order for the rest.
        Rows = BasicPrayersOrder.Apply(BasicPrayerCatalog.All)
            .Select(p =>
            {
                var name = PrayerCardName.ForBasicPrayer(p, language.Code);
                return new BasicPrayerRow(p.Id, name.Title, ImageFile(p.ImageKey),
                    AppSettings.FavoriteBasicPrayerIds.Contains(p.Id), name.InterfaceSubtitle);
            })
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
    private void Open(BasicPrayerRow row) => Navigation.Navigate<Views.BasicPrayerFlowPage>(row.Id);

    [RelayCommand]
    private void TogglePin(BasicPrayerRow row)
    {
        AppSettings.ToggleFavoriteBasicPrayer(row.Id);
        Load();
    }

    internal static string ImageFile(string imageKey) =>
        PrayerPackStore.ImageFileUriOrPlaceholder(imageKey);
}

/// <summary>One basic prayer as a bounded single-step flow: the same
/// <see cref="Prosary.Controls.PrayerStepFlowControl"/> chrome every devotion uses, with
/// "Finish" as its only footer action.</summary>
public partial class BasicPrayerViewModel : ObservableObject, IPrayerStepFlowViewModel
{
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;

    private string? _prayerId;

    public string HeaderFontFamily => PrayerTypography.ResolveHeadingFontFamily(Header);

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HeaderFontFamily))]
    private string _header = string.Empty;

    [ObservableProperty]
    private string _body = string.Empty;

    [ObservableProperty]
    private string _mysteryImageFile = "ms-appx:///Assets/Images/cross_placeholder.png";

    [ObservableProperty]
    private string _progressText = string.Empty;

    [ObservableProperty]
    private string _progressFontFamily = PrayerTypography.NativeUiFontFamily;

    private string? _initializedScriptLanguage;
    private string? _aramaicSessionScript;

    [ObservableProperty]
    private bool _isRightToLeft;

    [ObservableProperty]
    private string _bodyFontFamily = "Cambria";

    [ObservableProperty]
    private double _bodyFontSize = 18;

    [ObservableProperty]
    private bool _hasTransliteration;

    [ObservableProperty]
    private bool _showsTransliteration;

    public string CurrentLanguageRaw => AppSettings.BasicPrayersLanguageCode;

    public IReadOnlyList<LanguageOption> Languages => LanguageCatalog.PickerOptions;

    public void SelectLanguage(string code)
    {
        AppSettings.SetBasicPrayersLanguageCode(code);
        ShowsTransliteration = false;
        _initializedScriptLanguage = null;
        RenderPrayer();
    }

    [RelayCommand]
    private void ToggleTransliteration()
    {
        if (_aramaicSessionScript is not null)
            _aramaicSessionScript = _aramaicSessionScript == "Syrc" ? "Hebr" : "Syrc";
        else ShowsTransliteration = !ShowsTransliteration;
        RenderPrayer();
    }

    public string? Subtitle => null;

    public bool HasSubtitle => false;

    public double? Progress => 1.0;

    public Color SeasonColor => Microsoft.UI.Colors.Transparent;

    public bool CanGoBack => false;

    public string NextButtonText => Loc.Tr("common_finish", "Finish");

    public bool IsLastStep => true;

    public void Load(string prayerId)
    {
        _prayerId = prayerId;
        ShowsTransliteration = false;
        _initializedScriptLanguage = null;
        RenderPrayer();
    }

    public void RefreshTypography()
    {
        RenderPrayer();
        OnPropertyChanged(nameof(HeaderFontFamily));
    }
    public void RefreshPrayerWording() => RenderPrayer();

    private void RenderPrayer()
    {
        if (_prayerId is null || BasicPrayerCatalog.Prayer(_prayerId) is not { } prayer) return;
        var language = LanguageCatalog.Resolve(CurrentLanguageRaw);
        var step = BasicPrayerCatalog.Step(prayer, language.Code);
        if (_initializedScriptLanguage != language.Code)
        {
            _initializedScriptLanguage = language.Code;
            _aramaicSessionScript = language.Code == "arc" ? AppSettings.AramaicDefaultScript : null;
        }
        if (_aramaicSessionScript is not null)
            ShowsTransliteration = PrayerTranslations.InitialTransliteration(language.Code, step.Body, step.TransliteratedBody, _aramaicSessionScript) ?? false;
        HasTransliteration = step.TransliteratedBody is not null;
        Body = ShowsTransliteration && step.TransliteratedBody is { } transliterated
            ? transliterated
            : step.Body;
        var usesSyriacScript = PrayerTypography.ScriptOf(Body) == PrayerTypography.Script.Syriac;
        Header = PrayerTranslations.FlowTitle(step.Title, language.Code, usesSyriacScript, prayer.BundleId);
        MysteryImageFile = BasicPrayersViewModel.ImageFile(prayer.ImageKey);
        var aramaicProgress = PrayerTranslations.AramaicProgress(1, 1, language.Code, usesSyriacScript);
        ProgressText = aramaicProgress ?? string.Format(Loc.Tr("flow_step_of", "{0} of {1}"), 1, 1);
        ProgressFontFamily = aramaicProgress is null ? PrayerTypography.NativeUiFontFamily
            : PrayerTypography.ResolveBodyFontFamily(language.Code, false, PrayerTypography.ScriptOf(ProgressText));
        IsRightToLeft = language.IsRightToLeft;
        var bodyScript = PrayerTypography.ScriptOf(Body);
        IsRightToLeft = PrayerTypography.IsRightToLeft(bodyScript);
        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(language.Code, isScripture: false, script: bodyScript);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(language.Code, isScripture: false, script: bodyScript);
    }

    [RelayCommand]
    private void Next() => Navigation.GoBack();

    [RelayCommand]
    private void Back()
    {
    }
}
