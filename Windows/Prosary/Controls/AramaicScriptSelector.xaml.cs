using System.Windows.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;

namespace Prosary.Controls;

/// <summary>The same explicit alphabet choice in prayers, daily readings, and the Bible.</summary>
public sealed partial class AramaicScriptSelector : UserControl
{
    public static readonly DependencyProperty ScriptProperty = DependencyProperty.Register(
        nameof(Script), typeof(string), typeof(AramaicScriptSelector),
        new PropertyMetadata("Hebr", OnScriptChanged));
    public string Script
    {
        get => (string)GetValue(ScriptProperty);
        set => SetValue(ScriptProperty, value);
    }

    public static readonly DependencyProperty SelectScriptCommandProperty = DependencyProperty.Register(
        nameof(SelectScriptCommand), typeof(ICommand), typeof(AramaicScriptSelector), new PropertyMetadata(null));
    public ICommand? SelectScriptCommand
    {
        get => (ICommand?)GetValue(SelectScriptCommandProperty);
        set => SetValue(SelectScriptCommandProperty, value);
    }

    public AramaicScriptSelector()
    {
        InitializeComponent();
        var syriac = Loc.Tr("settings_script_syriac", "Syriac Script");
        var hebrew = Loc.Tr("settings_script_hebrew", "Hebrew Script");
        AutomationProperties.SetName(SyriacButton, syriac);
        AutomationProperties.SetName(HebrewButton, hebrew);
        AutomationProperties.SetAutomationId(SyriacButton, "scriptSyriac");
        AutomationProperties.SetAutomationId(HebrewButton, "scriptHebrew");
        ToolTipService.SetToolTip(SyriacButton, syriac);
        ToolTipService.SetToolTip(HebrewButton, hebrew);
        UpdateSelection();
    }

    private static void OnScriptChanged(DependencyObject sender, DependencyPropertyChangedEventArgs args) =>
        ((AramaicScriptSelector)sender).UpdateSelection();

    private void UpdateSelection()
    {
        if (SyriacButton is null) return;
        SyriacButton.IsChecked = Script == "Syrc";
        HebrewButton.IsChecked = Script != "Syrc";
    }

    private void Select(string script)
    {
        if (Script != script && SelectScriptCommand is { } command && command.CanExecute(script))
            command.Execute(script);
        UpdateSelection();
    }

    private void OnSyriac(object sender, RoutedEventArgs args) => Select("Syrc");
    private void OnHebrew(object sender, RoutedEventArgs args) => Select("Hebr");
}
