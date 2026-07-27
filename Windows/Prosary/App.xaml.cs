using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Prosary.Localization;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Prosary.Views;

namespace Prosary;

/// <summary>
/// Application entry point: builds the DI container (mirroring irosary's <c>MauiProgram.cs</c>
/// registrations, translated from MAUI's builder to <see cref="Microsoft.Extensions.DependencyInjection"/>)
/// and owns the single <see cref="MainWindow"/>.
/// </summary>
public partial class App : Application
{
    /// <summary>The process-wide DI container. Pages resolve their ViewModels/services through
    /// this rather than a Frame/Shell-provided mechanism, since plain WinUI3 has none built in.</summary>
    public static IServiceProvider Services { get; private set; } = null!;

    public static Window MainWindow { get; private set; } = null!;

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        Services = ConfigureServices();

        PrayerPackStore.Initialize(packName =>
        {
            var path = Path.Combine(AppContext.BaseDirectory, "PrayerPacks", $"{packName}.prosaryprayer");
            return File.Exists(path) ? File.OpenRead(path) : null;
        });

        MainWindow = new MainWindow();
        MainWindow.Activate();

        // Top up the reminder rolling window on every launch — the Windows equivalent of
        // Android's boot-time reschedule, since scheduled toasts (unlike AlarmManager alarms)
        // already survive reboot on their own and just need periodic re-arming so the window
        // never runs dry if the app isn't opened for weeks.
        _ = RescheduleRemindersAsync();
    }

    private static IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();

        services.AddSingleton<LiturgicalCalendarService>();
        services.AddSingleton<PrayerEngine>();
        services.AddSingleton<IPresetStore, SqlitePresetStore>();
        services.AddSingleton<IReminderScheduler, WindowsReminderScheduler>();

        services.AddTransient<HomeViewModel>();
        services.AddTransient<FavoritesViewModel>();
        services.AddTransient<FavoriteEditorViewModel>();
        services.AddTransient<RemindersOnlyEditorViewModel>();
        services.AddTransient<RosaryViewModel>();
        services.AddTransient<AngelusViewModel>();
        services.AddTransient<StationsViewModel>();
        services.AddTransient<FranciscanCrownViewModel>();
        services.AddTransient<SevenSorrowsViewModel>();
        services.AddTransient<DivineMercyViewModel>();
        services.AddTransient<JesusPrayerSetupViewModel>();
        services.AddTransient<JesusPrayerViewModel>();
        services.AddTransient<SettingsViewModel>();
        services.AddTransient<CustomDevotionViewModel>();

        return services.BuildServiceProvider();
    }

    private static async Task RescheduleRemindersAsync()
    {
        var presetStore = Services.GetRequiredService<IPresetStore>();
        var scheduler = Services.GetRequiredService<IReminderScheduler>();
        var prayers = await presetStore.GetAllAsync();
        scheduler.RescheduleAll(prayers);
    }
}
