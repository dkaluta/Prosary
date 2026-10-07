using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Services;

namespace Prosary.Controls;

/// <summary>Published context has its own language and direction, independently of the prayer.</summary>
public sealed partial class PopeIntentionPrayerCard : UserControl
{
    public static readonly DependencyProperty PublicationProperty = DependencyProperty.Register(
        nameof(Publication), typeof(PopeIntentionPrayerPublication), typeof(PopeIntentionPrayerCard),
        new PropertyMetadata(null, OnPublicationChanged));

    public PopeIntentionPrayerPublication? Publication
    {
        get => (PopeIntentionPrayerPublication?)GetValue(PublicationProperty);
        set => SetValue(PublicationProperty, value);
    }

    public PopeIntentionPrayerCard()
    {
        InitializeComponent();
        Refresh();
    }

    private static void OnPublicationChanged(DependencyObject sender, DependencyPropertyChangedEventArgs args) =>
        ((PopeIntentionPrayerCard)sender).Refresh();

    private void Refresh()
    {
        if (TitleText is null) return;
        Visibility = Publication is null ? Visibility.Collapsed : Visibility.Visible;
        if (Publication is not { } publication) return;
        FlowDirection = UiLanguageCatalog.IsRightToLeft(publication.LanguageCode)
            ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        TitleText.Text = publication.Title;
        BodyText.Text = publication.Text;
        SourceText.Text = Loc.Tr("prayer_pope_intention_source", "Pope’s Worldwide Prayer Network");
        CreditText.Text = publication.TranslationCredit ?? string.Empty;
        CreditText.Visibility = string.IsNullOrWhiteSpace(publication.TranslationCredit)
            ? Visibility.Collapsed : Visibility.Visible;
    }
}
