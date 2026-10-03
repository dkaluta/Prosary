using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class LiturgicalCalendarControl : UserControl
{
    public LiturgicalCalendarViewModel ViewModel { get; } = new();
    public Action<DateOnly>? SelectDate { get; set; }
    public LiturgicalCalendarControl()
    {
        InitializeComponent();
        Loaded += (_, _) => ViewModel.Refresh();
    }
    private void OnItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is LiturgicalCalendarRow row) SelectDate?.Invoke(row.Date);
    }
}
