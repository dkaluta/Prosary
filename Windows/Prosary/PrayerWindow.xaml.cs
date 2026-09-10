using Microsoft.Extensions.DependencyInjection;
using System.ComponentModel;
using Microsoft.UI.Xaml;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Prosary.Views;

namespace Prosary;

public sealed partial class PrayerWindow : Window
{
    private Guid? _savedID;
    public Guid? SavedPrayerID => _savedID;
    private bool _closed;
    private int _titleRevision;

    public PrayerWindow(Type pageType, object? parameter, Guid? savedID)
    {
        InitializeComponent();
        _savedID = savedID;
        Title = "Prosary";
        DesktopWindowChrome.Configure(this, WindowRoot, AppTitleBar, LeftPaddingColumn, RightPaddingColumn, 620);
        Router.Register(PrayerFrame, this, isPrayerWindow: true);
        DesktopWindowChrome.Populate(WindowMenus, this, PrayerFrame, () => _savedID);
        INotifyPropertyChanged? observedFlow = null;
        void FlowChanged(object? sender, PropertyChangedEventArgs args)
        {
            if (_savedID is null && args.PropertyName == "Header") _ = RefreshTitleAsync();
        }
        PrayerFrame.Navigated += (_, _) =>
        {
            if (observedFlow is not null) observedFlow.PropertyChanged -= FlowChanged;
            observedFlow = PrayerFrame.Content switch
            {
                RosaryPrayerPage page => page.ViewModel,
                CustomDevotionFlowPage page => page.ViewModel,
                JesusPrayerFlowPage page => page.ViewModel,
                BasicPrayerFlowPage page => page.ViewModel,
                _ => null,
            };
            if (observedFlow is not null) observedFlow.PropertyChanged += FlowChanged;
            _ = RefreshTitleAsync();
        };
        Closed += (_, _) =>
        {
            _closed = true;
            if (observedFlow is not null) observedFlow.PropertyChanged -= FlowChanged;
            Router.Unregister(PrayerFrame);
            PrayerFrame.Content = null;
        };
        Router.For(PrayerFrame).Navigate(pageType, parameter);
    }

    internal void AdoptSavedPrayer(Guid id)
    {
        _savedID = id;
        _ = RefreshTitleAsync();
    }

    public async Task RefreshTitleAsync()
    {
        var revision = ++_titleRevision;
        try
        {
            var name = _savedID is { } id
                ? (await App.Services.GetRequiredService<IPresetStore>().GetAsync(id))?.Name
                : PrayerFrame.Content switch
                {
                    RosaryPrayerPage page => page.ViewModel.Header,
                    CustomDevotionFlowPage page => page.ViewModel.Header,
                    JesusPrayerFlowPage page => page.ViewModel.Header,
                    BasicPrayerFlowPage page => page.ViewModel.Header,
                    _ => null,
                };
            if (_closed || revision != _titleRevision) return;
            Title = string.IsNullOrWhiteSpace(name) ? "Prosary" : $"{name} — Prosary";
            PrayerTitle.Text = Title;
        }
        catch (Exception error)
        {
            System.Diagnostics.Debug.WriteLine($"[PrayerWindow] Failed to refresh title: {error}");
        }
    }
}
