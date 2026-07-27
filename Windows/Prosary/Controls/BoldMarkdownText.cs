using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;

namespace Prosary.Controls;

/// <summary>
/// Attached property that renders a minimal "bold-only markdown" string (<c>**bold**</c> runs,
/// everything else plain) into a <see cref="TextBlock"/>'s <see cref="TextBlock.Inlines"/> —
/// WinUI's <c>TextBlock.Text</c> has no rich-text binding, so this is the smallest way to support
/// the traditional versicle/response typographic distinction (versicle in the body's normal
/// weight, response <c>**bold**</c>, no literal "V."/"R." labels — see
/// <c>PrayerEngine.BuildAngelusSteps</c> etc.) without a full Markdown library. Mirrors iOS's
/// <c>AttributedString(markdown:)</c> usage and Android's <c>parseBoldMarkdown()</c>.
/// </summary>
public static class BoldMarkdownText
{
    public static readonly DependencyProperty TextProperty = DependencyProperty.RegisterAttached(
        "Text", typeof(string), typeof(BoldMarkdownText), new PropertyMetadata(null, OnTextChanged));

    public static string GetText(TextBlock textBlock) => (string)textBlock.GetValue(TextProperty);

    public static void SetText(TextBlock textBlock, string value) => textBlock.SetValue(TextProperty, value);

    private static void OnTextChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not TextBlock textBlock) return;

        textBlock.Inlines.Clear();
        var remaining = (e.NewValue as string) ?? string.Empty;

        while (true)
        {
            var start = remaining.IndexOf("**", StringComparison.Ordinal);
            if (start < 0)
            {
                textBlock.Inlines.Add(new Run { Text = remaining });
                return;
            }

            var end = remaining.IndexOf("**", start + 2, StringComparison.Ordinal);
            if (end < 0)
            {
                textBlock.Inlines.Add(new Run { Text = remaining });
                return;
            }

            if (start > 0)
            {
                textBlock.Inlines.Add(new Run { Text = remaining[..start] });
            }
            textBlock.Inlines.Add(new Run { Text = remaining[(start + 2)..end], FontWeight = FontWeights.Bold });
            remaining = remaining[(end + 2)..];
        }
    }
}
