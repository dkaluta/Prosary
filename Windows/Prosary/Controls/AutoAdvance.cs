using System.ComponentModel;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml.Controls;
using Prosary.Models;
using Prosary.ViewModels;

namespace Prosary.Controls;

/// <summary>Hands-free advancing for the prayer flow pages: waits
/// <see cref="AppSettings.AutoAdvanceSeconds"/> after every step render and executes the
/// ViewModel's NextCommand — the Windows mirror of iOS's PrayerStepFlowView timer task and
/// Android's LaunchedEffect. ProgressText changes on every render (including the Jesus Prayer's
/// running count), so listening to it makes manual Back/Next reset the countdown. Never fires on
/// the last step: auto-"Finish" would dismiss the whole flow mid-prayer. Owned by page
/// code-behind — created after load, disposed on navigate-away.</summary>
public sealed class AutoAdvanceTimer : IDisposable
{
    private readonly DispatcherQueueTimer _timer;
    private readonly IPrayerStepFlowViewModel _viewModel;

    public AutoAdvanceTimer(IPrayerStepFlowViewModel viewModel)
    {
        _viewModel = viewModel;
        _timer = DispatcherQueue.GetForCurrentThread().CreateTimer();
        _timer.IsRepeating = false;
        _timer.Tick += (_, _) =>
        {
            // A playing recording drives the steps through its chapters — the timer stands
            // down rather than fight it (pausing re-arms via the next ProgressText render).
            if (_viewModel is IAudioAwareStepFlowViewModel { IsAudioPlaying: true })
            {
                return;
            }

            if (!_viewModel.IsLastStep)
            {
                _viewModel.NextCommand.Execute(null);
            }
        };
        _viewModel.PropertyChanged += OnViewModelPropertyChanged;
        Restart();
    }

    /// <summary>Arms (or re-arms) the countdown from the current setting; stops it when off.</summary>
    public void Restart()
    {
        _timer.Stop();
        var seconds = AppSettings.AutoAdvanceSeconds;
        if (seconds <= 0 || _viewModel.IsLastStep)
        {
            return;
        }

        _timer.Interval = TimeSpan.FromSeconds(seconds);
        _timer.Start();
    }

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(IPrayerStepFlowViewModel.ProgressText))
        {
            Restart();
        }
    }

    public void Dispose()
    {
        _viewModel.PropertyChanged -= OnViewModelPropertyChanged;
        _timer.Stop();
    }
}

/// <summary>Builds the shared Off / every-3/5/10/15-seconds flyout (MenuFlyout has no ItemsSource —
/// the same rebuild-on-click pattern as the pages' variant flyouts).</summary>
public static class AutoAdvanceMenu
{
    private static readonly int[] Choices = [0, 3, 5, 10, 15];

    public static void Populate(MenuFlyout flyout, Action onChanged)
    {
        flyout.Items.Clear();
        foreach (var seconds in Choices)
        {
            var item = new ToggleMenuFlyoutItem
            {
                Text = seconds == 0 ? Localization.Loc.Tr("auto_advance_off", "Off")
                    : string.Format(Localization.Loc.Tr("auto_advance_every", "Every {0} seconds"), seconds),
                IsChecked = AppSettings.AutoAdvanceSeconds == seconds,
            };
            item.Click += (_, _) =>
            {
                AppSettings.SetAutoAdvanceSeconds(seconds);
                Populate(flyout, onChanged);
                onChanged();
            };
            flyout.Items.Add(item);
        }
    }
}
