using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;

namespace Prosary.Navigation;

/// <summary>
/// Thin wrapper around the root <see cref="Frame"/>'s typed page navigation — plain WinUI3's
/// equivalent of irosary's <c>Shell.Current.GoToAsync(...)</c> calls, adapted from Shell's
/// string-route query params to typed pages plus a navigation-parameter object per page (see
/// each page's constructor/<c>OnNavigatedTo</c> for its expected parameter type).
/// </summary>
public static class Router
{
    private static Frame? _frame;
    private static object? _currentParameter;

    public static void Initialize(Frame frame)
    {
        if (_frame is not null)
        {
            _frame.Navigated -= OnNavigated;
        }

        _frame = frame;
        _currentParameter = null;
        _frame.Navigated += OnNavigated;
    }

    public static void Navigate<TPage>(object? parameter = null) where TPage : Page
    {
        if (_frame is null
            || IsDuplicateNavigation(
                _frame.CurrentSourcePageType,
                _currentParameter,
                typeof(TPage),
                parameter))
        {
            return;
        }

        _frame.Navigate(typeof(TPage), parameter);
    }

    internal static bool IsDuplicateNavigation(
        Type? currentPageType,
        object? currentParameter,
        Type destinationPageType,
        object? destinationParameter) =>
        currentPageType == destinationPageType
        && object.Equals(currentParameter, destinationParameter);

    private static void OnNavigated(object sender, NavigationEventArgs args)
    {
        _currentParameter = args.Parameter;
    }

    public static bool CanGoBack => _frame?.CanGoBack ?? false;

    public static void GoBack()
    {
        if (_frame?.CanGoBack == true)
        {
            _frame.GoBack();
        }
    }

    /// <summary>Pops every pushed page back to Home — used where a multi-level flow (e.g. Jesus
    /// Prayer Setup → Flow) should return all the way to Home on finish, not one level up,
    /// mirroring iOS/Android's equivalent "pop to root" navigation calls.</summary>
    public static void PopToRoot()
    {
        while (_frame?.CanGoBack == true)
        {
            _frame.GoBack();
        }
    }
}
