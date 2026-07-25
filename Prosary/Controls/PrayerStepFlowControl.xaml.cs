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

    public PrayerStepFlowControl()
    {
        InitializeComponent();
    }
}
