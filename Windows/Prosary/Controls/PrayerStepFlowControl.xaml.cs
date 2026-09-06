using Prosary.Services;
using Prosary.Localization;
using Prosary.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;

namespace Prosary.Controls;

public sealed partial class PrayerStepFlowControl : UserControl
{
    public static readonly DependencyProperty ViewModelProperty = DependencyProperty.Register(
        nameof(ViewModel), typeof(IPrayerStepFlowViewModel), typeof(PrayerStepFlowControl), new PropertyMetadata(null));

    public IPrayerStepFlowViewModel? ViewModel
    {
        get => (IPrayerStepFlowViewModel?)GetValue(ViewModelProperty);
        set => SetValue(ViewModelProperty, value);
    }

    /// <summary>When set ("Pray" — the Jesus Prayer), a large round button below the text becomes
    /// the flow's one big tap target and replaces the footer's Next entirely — for a counter
    /// flow, advancing is the only action, so it deserves more than a corner button.</summary>
    public static readonly DependencyProperty CentralActionLabelProperty = DependencyProperty.Register(
        nameof(CentralActionLabel), typeof(string), typeof(PrayerStepFlowControl), new PropertyMetadata(null));

    public string? CentralActionLabel
    {
        get => (string?)GetValue(CentralActionLabelProperty);
        set => SetValue(CentralActionLabelProperty, value);
    }

    public Visibility VisibleWhenSet(string? label) =>
        string.IsNullOrEmpty(label) ? Visibility.Collapsed : Visibility.Visible;

    public Visibility CollapsedWhenSet(string? label) =>
        string.IsNullOrEmpty(label) ? Visibility.Visible : Visibility.Collapsed;

    public PrayerStepFlowControl()
    {
        InitializeComponent();
        Loaded += (_, _) => { AppSettings.TypographyChanged += OnTypographyChanged; OnTypographyChanged(); };
        Unloaded += (_, _) => AppSettings.TypographyChanged -= OnTypographyChanged;
    }
    private void OnTypographyChanged() => ViewModel?.RefreshTypography();

    // UI navigation stays independent of the displayed prayer's writing system.
    public FlowDirection NavigationFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
        ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public string PreviousNavigationGlyph => PrayerNavigation.PreviousGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);
    public string NextNavigationGlyph => PrayerNavigation.NextGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);

}
