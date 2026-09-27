using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Prosary.Localization;
using Prosary.Services;

namespace Prosary.Controls;

/// <summary>Editorial disclosures stay outside the selectable Scripture text.</summary>
public sealed class ScriptureSourceNotesControl : UserControl
{
    public static readonly DependencyProperty SourceNotesProperty = DependencyProperty.Register(
        nameof(SourceNotes), typeof(object), typeof(ScriptureSourceNotesControl), new PropertyMetadata(null, OnNotesChanged));
    public object? SourceNotes { get => GetValue(SourceNotesProperty); set => SetValue(SourceNotesProperty, value); }
    private static void OnNotesChanged(DependencyObject sender, DependencyPropertyChangedEventArgs args) =>
        ((ScriptureSourceNotesControl)sender).Refresh();

    public ScriptureSourceNotesControl()
    {
        FontFamily = new FontFamily("Segoe UI");
        FontSize = 14;
        FlowDirection = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        Visibility = Visibility.Collapsed;
    }

    private void Refresh()
    {
        var notes = SourceNotes as IReadOnlyList<ScriptureSourceNote>;
        Visibility = notes is { Count: > 0 } ? Visibility.Visible : Visibility.Collapsed;
        var list = new StackPanel { Spacing = 6, Margin = new Thickness(0, 8, 0, 0) };
        foreach (var note in notes ?? [])
        {
            var detail = new StackPanel { Spacing = 8 };
            detail.Children.Add(new TextBlock { Text = note.Anchor, FlowDirection = FlowDirection.RightToLeft,
                TextWrapping = TextWrapping.Wrap, FontFamily = new FontFamily(PrayerTypography.ResolveBodyFontFamily("he", true, PrayerTypography.Script.Hebrew)),
                FontSize = PrayerTypography.ResolveBodyFontSize("he", true, PrayerTypography.Script.Hebrew) });
            detail.Children.Add(new TextBlock { Text = string.Format(Loc.Tr("scripture_note_letter", "Letter {0} (position {1})"),
                "\u2067" + note.Letter() + "\u2069", note.LetterIndex), TextWrapping = TextWrapping.Wrap });
            detail.Children.Add(new TextBlock { Text = note.Mark == "vowel"
                ? Loc.Tr("scripture_note_vowel", "Unreadable vowel mark omitted.")
                : Loc.Tr("scripture_note_dagesh", "Unreadable dagesh omitted."), TextWrapping = TextWrapping.Wrap });
            detail.Children.Add(new TextBlock { Text = string.Format(Loc.Tr("scripture_note_pages", "PDF pages: {0}"),
                string.Join(", ", note.SourcePages)), TextWrapping = TextWrapping.Wrap });
            detail.Children.Add(new HyperlinkButton { Content = Loc.Tr("scripture_note_scan", "Source scan"),
                NavigateUri = new Uri(note.SourceURL), Padding = new Thickness(0) });
            list.Children.Add(new Expander { Header = Loc.Tr("scripture_note_title", "Source note"),
                Content = detail, HorizontalAlignment = HorizontalAlignment.Stretch, HorizontalContentAlignment = HorizontalAlignment.Stretch });
        }
        Content = list;
    }
}
