using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;
using Prosary.ViewModels;
using Windows.Foundation;

namespace Prosary.Controls;

/// <summary>Keeps the first visible text line across both window reflow and the two flow
/// layouts. Stores TextPointer offsets (including inline formatting), shared by both copies of
/// the body, and never changes prayer/session state.</summary>
public sealed class PrayerFlowReader
{
    private ScrollViewer _scroll;
    private TextBlock _body;
    private PrayerReadingAnchor _anchor;
    private Geometry? _geometry;
    private bool _pendingRestore = true;
    private bool _queued;
    private bool _restoring;
    private double _restoreTarget;
    private string? _content;

    private readonly record struct Geometry(double Width, double Height, double BodyWidth, double BodyHeight, double BodyTop);

    public PrayerFlowReader(ScrollViewer scroll, TextBlock body)
    {
        _scroll = scroll;
        _body = body;
        Register(scroll, body);
    }

    public void Register(ScrollViewer scroll, TextBlock body)
    {
        scroll.ViewChanged += OnViewChanged;
        scroll.Loaded += (_, _) => { if (scroll == _scroll) RequestRestore(); };
        scroll.LayoutUpdated += (_, _) =>
        {
            if (scroll == _scroll && scroll.IsLoaded && (_pendingRestore || ReadGeometry() != _geometry))
                RequestRestore();
        };
    }

    public void UseSurface(ScrollViewer scroll, TextBlock body)
    {
        if (_scroll == scroll) return;
        _scroll = scroll;
        _body = body;
        _geometry = null;
        _restoring = false;
        RequestRestore();
    }

    public void Reset()
    {
        _anchor = default;
        RequestRestore();
    }

    private Geometry ReadGeometry() => new(_scroll.ActualWidth, _scroll.ActualHeight,
        _body.ActualWidth, _body.ActualHeight,
        Math.Round(_body.TransformToVisual(_scroll).TransformPoint(new Point()).Y + _scroll.VerticalOffset, 2));

    private Rect CharacterRect(int offset) => _body.ContentStart
        .GetPositionAtOffset(offset, LogicalDirection.Forward)?
        .GetCharacterRect(LogicalDirection.Forward) ?? new Rect();

    private void OnViewChanged(object? sender, ScrollViewerViewChangedEventArgs e)
    {
        if (sender is not ScrollViewer scroll || scroll != _scroll || !_scroll.IsLoaded) return;
        if (_restoring && Math.Abs(_scroll.VerticalOffset - _restoreTarget) < 0.5)
        {
            if (!e.IsIntermediate) _restoring = false;
            return;
        }
        _restoring = false;
        if (_pendingRestore) return;
        var geometry = ReadGeometry();
        // Resizing can clamp VerticalOffset before SizeChanged/LayoutUpdated is delivered.
        // Keep the last reader-chosen text anchor instead of capturing that clamped position.
        if (geometry != _geometry)
        {
            RequestRestore();
            return;
        }

        var bodyTop = geometry.BodyTop;
        _content = BoldMarkdownText.GetText(_body);
        if (_scroll.VerticalOffset <= bodyTop)
        {
            _anchor = PrayerReadingAnchor.BeforeBody(_scroll.VerticalOffset, bodyTop);
            return;
        }
        var textTop = _scroll.VerticalOffset - bodyTop;
        var symbolCount = _body.ContentEnd.Offset - _body.ContentStart.Offset;
        var offset = PrayerReadingAnchor.FirstVisibleOffset(symbolCount, textTop, i =>
        {
            var rect = CharacterRect(i);
            return (rect.Y, rect.Height);
        });
        var character = CharacterRect(offset);
        if (character.Height > 0)
            _anchor = new(offset, Math.Clamp((textTop - character.Y) / character.Height, 0, 1), 0);
    }

    private void RequestRestore()
    {
        _pendingRestore = true;
        if (_queued) return;
        _queued = _scroll.DispatcherQueue.TryEnqueue(DispatcherQueuePriority.Low, Restore);
    }

    private void Restore()
    {
        _queued = false;
        if (!_scroll.IsLoaded || _scroll.ActualHeight <= 0 || _body.ActualHeight <= 0) return;
        _scroll.UpdateLayout();
        var content = BoldMarkdownText.GetText(_body);
        if (_content != content) _anchor = default;
        _content = content;
        var geometry = ReadGeometry();
        var character = _anchor.TextOffset is { } offset ? CharacterRect(offset) : new Rect();
        var target = _anchor.ScrollOffset(geometry.BodyTop, character.Y, character.Height, _scroll.ScrollableHeight);
        _geometry = geometry;
        _pendingRestore = false;
        _restoreTarget = target;
        _restoring = true;
        if (!_scroll.ChangeView(null, target, null, disableAnimation: true)) _restoring = false;
    }
}
