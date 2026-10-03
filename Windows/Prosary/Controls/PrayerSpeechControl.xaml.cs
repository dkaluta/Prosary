using System.ComponentModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Services;
using Prosary.ViewModels;

namespace Prosary.Controls;

public sealed partial class PrayerSpeechControl : UserControl
{
    private readonly PrayerSpeechService _speech = new();
    public static readonly DependencyProperty ViewModelProperty = DependencyProperty.Register(
        nameof(ViewModel), typeof(IPrayerStepFlowViewModel), typeof(PrayerSpeechControl),
        new PropertyMetadata(null, OnModelChanged));
    public IPrayerStepFlowViewModel? ViewModel
    {
        get => (IPrayerStepFlowViewModel?)GetValue(ViewModelProperty);
        set => SetValue(ViewModelProperty, value);
    }

    public PrayerSpeechControl()
    {
        InitializeComponent();
        _speech.StateChanged += Update;
        Loaded += (_, _) =>
        {
            if (ViewModel is { } model) model.PropertyChanged += OnFlowChanged;
            Update();
        };
        Unloaded += (_, _) =>
        {
            if (ViewModel is { } model) model.PropertyChanged -= OnFlowChanged;
            _speech.Stop();
        };
    }

    private static void OnModelChanged(DependencyObject sender, DependencyPropertyChangedEventArgs args)
    {
        var control = (PrayerSpeechControl)sender;
        control._speech.Stop();
        if (control.IsLoaded)
        {
            if (args.OldValue is IPrayerStepFlowViewModel old) old.PropertyChanged -= control.OnFlowChanged;
            if (args.NewValue is IPrayerStepFlowViewModel next) next.PropertyChanged += control.OnFlowChanged;
        }
        control.Update();
    }

    private void OnFlowChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName is nameof(IPrayerStepFlowViewModel.Body) or nameof(IPrayerStepFlowViewModel.ProgressText)
            or nameof(IPrayerStepFlowViewModel.SpeechBody) or nameof(IPrayerStepFlowViewModel.SpeechLanguageCode)
            or "HasSavedContinuation" or "ShowsMissedDayChoice" or "ShowsCompletionSuggestion"
            || ViewModel is IAudioAwareStepFlowViewModel { IsAudioPlaying: true }) _speech.Stop();
        if (args.PropertyName is "Body" or "HasAudio" or "IsAudioPlaying" or "HasSavedContinuation"
            or "ShowsMissedDayChoice" or "ShowsCompletionSuggestion") Update();
    }

    private void Update()
    {
        if (ReadButton is null) return;
        Visibility = ViewModel is IAudioAwareStepFlowViewModel { HasRecordedNarration: true }
            ? Visibility.Collapsed : Visibility.Visible;
        ReadButton.Content = _speech.IsSpeaking ? Loc.Tr("speech_stop", "Stop reading") : Loc.Tr("speech_read", "Read aloud");
        if (_speech.Failed)
        {
            UnavailableText.Text = Loc.Tr("speech_unavailable_message", "Install a system voice for this prayer’s language to read it aloud.");
            UnavailableText.Visibility = Visibility.Visible;
        }
        var hasPrompt = ViewModel switch
        {
            CustomDevotionViewModel custom => custom.HasSavedContinuation || custom.ShowsMissedDayChoice || custom.ShowsCompletionSuggestion,
            RosaryViewModel rosary => rosary.HasSavedContinuation,
            JesusPrayerViewModel jesus => jesus.HasSavedContinuation,
            _ => false,
        };
        ReadButton.IsEnabled = ViewModel is { } model && !string.IsNullOrEmpty(model.SpeechBody)
            && !hasPrompt && model is not IAudioAwareStepFlowViewModel { IsAudioPlaying: true };
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(ReadButton, ReadButton.Content?.ToString() ?? string.Empty);
    }

    private async void OnRead(object sender, RoutedEventArgs args)
    {
        UnavailableText.Visibility = Visibility.Collapsed;
        if (_speech.IsSpeaking) _speech.Stop();
        else if (ViewModel is { } model && !await _speech.SpeakAsync(model))
        {
            UnavailableText.Text = Loc.Tr("speech_unavailable_message", "Install a system voice for this prayer’s language to read it aloud.");
            UnavailableText.Visibility = Visibility.Visible;
        }
    }
}
