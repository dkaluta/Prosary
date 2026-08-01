using CommunityToolkit.Mvvm.Input;
using Microsoft.UI;
using Windows.UI;

namespace Prosary.ViewModels;

/// <summary>
/// Common binding contract for any linear prayer flow's shared chrome (season-color bar,
/// progress readout, image + text block, Back/Next-or-Finish footer) — implemented by
/// <see cref="RosaryViewModel"/>, <see cref="CustomDevotionViewModel"/>, and
/// <see cref="JesusPrayerViewModel"/> so <c>Controls/PrayerStepFlowControl.xaml</c> can bind to
/// one shared <see cref="Microsoft.UI.Xaml.Controls.UserControl.DataContext"/> contract instead
/// of three near-duplicate XAML layouts. Mirrors iOS's shared <c>PrayerStepFlowView.swift</c>.
/// </summary>
public interface IPrayerStepFlowViewModel : System.ComponentModel.INotifyPropertyChanged
{
    string Header { get; }
    string? Subtitle { get; }
    bool HasSubtitle { get; }
    string Body { get; }

    /// <summary>Full <c>ms-appx:///Assets/Images/{key}.jpg</c>-style URI, ready to bind directly
    /// to an <see cref="Microsoft.UI.Xaml.Controls.Image.Source"/>.</summary>
    string MysteryImageFile { get; }

    string ProgressText { get; }

    /// <summary>0–1 fraction for a bounded flow; null for an open-ended one (unbounded Jesus
    /// Prayer), which hides the progress bar and shows only <see cref="ProgressText"/>'s running
    /// count.</summary>
    double? Progress { get; }

    bool IsRightToLeft { get; }
    Color SeasonColor { get; }
    string BodyFontFamily { get; }
    double BodyFontSize { get; }
    bool CanGoBack { get; }
    string NextButtonText { get; }

    /// <summary>True when Next would finish/dismiss the flow — the auto-advance timer
    /// (<see cref="Prosary.Controls.AutoAdvanceTimer"/>) never fires then, so a hands-free
    /// session stops on the last step instead of closing itself mid-prayer. For the Jesus
    /// Prayer this is the bounded session's last repetition; an unbounded one never ends.</summary>
    bool IsLastStep { get; }

    IRelayCommand NextCommand { get; }
    IRelayCommand BackCommand { get; }
}

/// <summary>Optional add-on contract for a flow that can play a bundle's narrated recording
/// (today only <see cref="CustomDevotionViewModel"/>): while the recording plays, its chapters
/// drive the steps, so <see cref="Prosary.Controls.AutoAdvanceTimer"/> stands down instead of
/// fighting it — the Windows mirror of the audioIsPlaying guard on iOS/Android.</summary>
public interface IAudioAwareStepFlowViewModel
{
    bool IsAudioPlaying { get; }
}
