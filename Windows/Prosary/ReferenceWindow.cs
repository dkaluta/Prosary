using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Navigation;
using Prosary.Services;
using Prosary.ViewModels;
using Prosary.Views;

namespace Prosary;

/// <summary>Home's calendar is an independent native reference window.</summary>
public sealed class ReferenceWindow : Window
{
    public ReferenceWindow(HomeViewModel? today, Action<DateOnly> openReadings)
    {
        Title = Loc.Tr("calendar_events_title", "Event Calendar");
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var titleBar = new Grid { Height = 48 };
        var leftInset = new ColumnDefinition { Width = new GridLength(0) };
        var rightInset = new ColumnDefinition { Width = new GridLength(0) };
        titleBar.ColumnDefinitions.Add(leftInset);
        titleBar.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        titleBar.ColumnDefinitions.Add(rightInset);
        var title = new TextBlock { Text = Title, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(16, 0, 16, 0), FontSize = 12 };
        Grid.SetColumn(title, 1);
        titleBar.Children.Add(title);
        root.Children.Add(titleBar);
        var menus = new MenuBar { Margin = new Thickness(8, 0, 8, 4), MinHeight = 32 };
        Grid.SetRow(menus, 1);
        root.Children.Add(menus);
        var frame = new Frame();
        Grid.SetRow(frame, 2);
        root.Children.Add(frame);
        Content = root;
        DesktopWindowChrome.Configure(this, root, titleBar, leftInset, rightInset, 620);
        Router.Register(frame, this);
        DesktopWindowChrome.Populate(menus, this, frame);
        var calendar = new LiturgicalCalendarControl();
        calendar.FocusOnDate(today?.SelectedDate ?? DateOnly.FromDateTime(DateTime.Today));
        calendar.SelectDate = date => { Close(); openReadings(date); };
        frame.Content = new Page { Content = calendar };
        Closed += (_, _) => { Router.Unregister(frame); frame.Content = null; };
    }
}
