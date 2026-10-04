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
        if (notes is not { Count: > 0 }) { Content = null; return; }
        var detail = new StackPanel { Spacing = 12 };
        foreach (var sourceNotes in notes.GroupBy(note => (note.SourceURL, Pages: string.Join(",", note.SourcePages))))
        {
            var sourceDetail = new StackPanel { Spacing = 8 };
            foreach (var anchorNotes in sourceNotes.GroupBy(note => (note.Anchor, note.Occurrence)))
            {
                var anchorDetail = new StackPanel { Spacing = 8 };
                anchorDetail.Children.Add(new TextBlock { Text = anchorNotes.Key.Anchor, FlowDirection = FlowDirection.RightToLeft,
                    TextWrapping = TextWrapping.Wrap, FontFamily = new FontFamily(PrayerTypography.ResolveBodyFontFamily("he", true, PrayerTypography.Script.Hebrew)),
                    FontSize = PrayerTypography.ResolveBodyFontSize("he", true, PrayerTypography.Script.Hebrew) });
                foreach (var note in anchorNotes)
                {
                    var noteDetail = new StackPanel { Spacing = 4 };
                    if (note.Kind == "restoredLetter")
                        noteDetail.Children.Add(new TextBlock { Text = string.Format(Loc.Tr("scripture_note_restored_letter",
                            "The letter {0} (position {1}) in “{2}” was restored editorially. It is unreadable in the source scan."),
                            "\u2067" + note.Letter() + "\u2069", note.LetterIndex, "\u2067" + note.Anchor + "\u2069"), TextWrapping = TextWrapping.Wrap });
                    else
                    {
                        noteDetail.Children.Add(new TextBlock { Text = string.Format(Loc.Tr("scripture_note_letter", "Letter {0} (position {1})"),
                            "\u2067" + note.Letter() + "\u2069", note.LetterIndex), TextWrapping = TextWrapping.Wrap });
                        noteDetail.Children.Add(new TextBlock { Text = note.Mark is "vowel" or "shuruq"
                            ? Loc.Tr("scripture_note_vowel", "Unreadable vowel mark omitted.")
                            : Loc.Tr("scripture_note_dagesh", "Unreadable dagesh omitted."), TextWrapping = TextWrapping.Wrap });
                    }
                    anchorDetail.Children.Add(noteDetail);
                }
                sourceDetail.Children.Add(anchorDetail);
            }
            var source = sourceNotes.First();
            sourceDetail.Children.Add(new TextBlock { Text = string.Format(Loc.Tr("scripture_note_pages", "PDF pages: {0}"),
                string.Join(", ", source.SourcePages)), TextWrapping = TextWrapping.Wrap });
            sourceDetail.Children.Add(new HyperlinkButton { Content = Loc.Tr("scripture_note_scan", "Source scan"),
                NavigateUri = new Uri(source.SourceURL), Padding = new Thickness(0) });
            detail.Children.Add(sourceDetail);
        }
        Content = new Expander { Header = Loc.Tr("scripture_note_title", "Source note"), Content = detail,
            Margin = new Thickness(0, 8, 0, 0), HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Stretch };
    }
}
