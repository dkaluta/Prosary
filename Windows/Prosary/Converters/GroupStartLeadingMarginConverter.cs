using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace Prosary.Converters;

/// <summary>Extra leading margin for a bead marking a group-of-5 boundary — used only by the
/// narrow layout's single-row minor (current-decade) beads, matching iOS's
/// <c>MinorBeadsRowView</c> exactly (<c>.padding(.leading, bead.isGroupStart ? beadSpacing : 0)</c>
/// stacked on top of the row's own uniform spacing). Not used anywhere beads render in a column
/// (major-bead rows/columns, wide minor-bead column(s)) — iOS doesn't add this there either.</summary>
public sealed class GroupStartLeadingMarginConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is true ? new Thickness(6, 0, 0, 0) : new Thickness(0);

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
