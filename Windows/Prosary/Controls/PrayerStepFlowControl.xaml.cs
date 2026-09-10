using Prosary.Services;
using Prosary.Localization;
using Prosary.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;
using System.ComponentModel;

namespace Prosary.Controls;

public sealed partial class PrayerStepFlowControl : UserControl
{
    private readonly PrayerFlowReader _reader;
    private (bool, string, string)? _lastPrayerWording;

    public static readonly DependencyProperty ViewModelProperty = DependencyProperty.Register(
        nameof(ViewModel), typeof(IPrayerStepFlowViewModel), typeof(PrayerStepFlowControl), new PropertyMetadata(null, OnViewModelChanged));

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
        _reader = new PrayerFlowReader(Reader, PrayerBody);
        Loaded += (_, _) =>
        {
            AppSettings.TypographyChanged += OnTypographyChanged;
            AppSettings.PrayerWordingChanged += OnPrayerWordingChanged;
            if (ViewModel is { } model) model.PropertyChanged += OnFlowPropertyChanged;
            OnPrayerWordingChanged();
            OnTypographyChanged();
        };
        Unloaded += (_, _) =>
        {
            AppSettings.TypographyChanged -= OnTypographyChanged;
            AppSettings.PrayerWordingChanged -= OnPrayerWordingChanged;
            if (ViewModel is { } model) model.PropertyChanged -= OnFlowPropertyChanged;
        };
    }

    private static void OnViewModelChanged(DependencyObject sender, DependencyPropertyChangedEventArgs e)
    {
        var control = (PrayerStepFlowControl)sender;
        if (control.IsLoaded)
        {
            if (e.OldValue is IPrayerStepFlowViewModel oldModel) oldModel.PropertyChanged -= control.OnFlowPropertyChanged;
            if (e.NewValue is IPrayerStepFlowViewModel newModel) newModel.PropertyChanged += control.OnFlowPropertyChanged;
        }
        control._reader?.Reset();
    }

    private void OnFlowPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(IPrayerStepFlowViewModel.Body) or nameof(IPrayerStepFlowViewModel.Progress))
            _reader.Reset();
    }

    private void OnTypographyChanged() => ViewModel?.RefreshTypography();
    private void OnPrayerWordingChanged()
    {
        var wording = (AppSettings.UseJaffaHailMaryWording, AppSettings.AramaicSignOfCrossForm, AppSettings.DefaultLanguageCode);
        if (_lastPrayerWording == wording) return;
        _lastPrayerWording = wording;
        ViewModel?.RefreshPrayerWording();
    }

    // UI navigation stays independent of the displayed prayer's writing system.
    public FlowDirection NavigationFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
        ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public string PreviousNavigationGlyph => PrayerNavigation.PreviousGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);
    public string NextNavigationGlyph => PrayerNavigation.NextGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);

}
