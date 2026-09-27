using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;
using Prosary.ViewModels;

namespace Prosary.Controls;

/// <summary>Per-verse selectable text allows editorial notes to remain adjacent but separate.</summary>
public sealed class ScripturePassageBody : UserControl
{
    public static readonly DependencyProperty ChaptersProperty = DependencyProperty.Register(
        nameof(Chapters), typeof(object), typeof(ScripturePassageBody), new PropertyMetadata(null, OnChaptersChanged));
    public object? Chapters { get => GetValue(ChaptersProperty); set => SetValue(ChaptersProperty, value); }
    private static void OnChaptersChanged(DependencyObject sender, DependencyPropertyChangedEventArgs args)
    {
        var body = (ScripturePassageBody)sender;
        var chapters = args.NewValue as IReadOnlyList<ReadingChapterSection> ?? [];
        if (chapters.All(chapter => chapter.Verses?.All(verse => verse.SourceNotes is null) != false))
        {
            // Keep the existing whole-passage selection behavior for ordinary readings.
            var text = new TextBlock { TextWrapping = TextWrapping.Wrap, IsTextSelectionEnabled = true };
            ScripturePassageText.SetChapters(text, chapters);
            body.Content = text;
            return;
        }
        var stack = new StackPanel { Spacing = 16 };
        foreach (var chapter in chapters)
        {
            var section = new StackPanel { Spacing = 12 };
            var heading = new TextBlock { TextWrapping = TextWrapping.Wrap, IsTextSelectionEnabled = true };
            heading.Inlines.Add(new Run { Text = chapter.Label + " ", FontWeight = FontWeights.Bold });
            heading.Inlines.Add(new Run { Text = $"\u2068{chapter.DisplayNumber}\u2069" });
            section.Children.Add(heading);
            foreach (var verse in chapter.Verses ?? [])
            {
                var row = new StackPanel();
                row.Children.Add(new TextBlock { Text = verse.DisplayText, TextWrapping = TextWrapping.Wrap, IsTextSelectionEnabled = true });
                row.Children.Add(new ScriptureSourceNotesControl { SourceNotes = verse.SourceNotes });
                section.Children.Add(row);
            }
            stack.Children.Add(section);
        }
        body.Content = stack;
    }
}
