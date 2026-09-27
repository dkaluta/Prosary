using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;
using Prosary.ViewModels;

namespace Prosary.Controls;

/// <summary>One selectable Scripture body with chapter headings and verse-only numbering.</summary>
public static class ScripturePassageText
{
    public static readonly DependencyProperty ChaptersProperty = DependencyProperty.RegisterAttached(
        "Chapters", typeof(object), typeof(ScripturePassageText), new PropertyMetadata(null, OnChaptersChanged));

    public static object GetChapters(TextBlock textBlock) => textBlock.GetValue(ChaptersProperty);
    public static void SetChapters(TextBlock textBlock, object value) => textBlock.SetValue(ChaptersProperty, value);

    private static void OnChaptersChanged(DependencyObject sender, DependencyPropertyChangedEventArgs args)
    {
        if (sender is not TextBlock textBlock) return;
        textBlock.Inlines.Clear();
        if (args.NewValue is not IReadOnlyList<ReadingChapterSection> chapters) return;
        foreach (var chapter in chapters)
        {
            if (textBlock.Inlines.Count > 0)
            {
                textBlock.Inlines.Add(new LineBreak());
                textBlock.Inlines.Add(new LineBreak());
            }
            textBlock.Inlines.Add(new Run { Text = chapter.Label + " ", FontWeight = FontWeights.Bold });
            textBlock.Inlines.Add(new Run { Text = $"\u2066{chapter.Number}\u2069", FontStyle = Windows.UI.Text.FontStyle.Italic });
            textBlock.Inlines.Add(new LineBreak());
            textBlock.Inlines.Add(new Run { Text = chapter.Text });
        }
    }
}
