using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>The resume rule the playback service persists positions by — the same rule on all
/// three platforms: past the first moments, short of the last stretch.</summary>
public class AudioPositionRuleTests
{
    [Theory]
    [InlineData(9, 100, false)]   // barely started — begin fresh
    [InlineData(11, 100, true)]   // mid-session — resume
    [InlineData(91, 100, false)]  // nearly done — begin fresh
    [InlineData(15, 0, false)]    // no known duration — never resume blind
    public void RestoreRuleSkipsTheEdges(double position, double duration, bool expected)
        => Assert.Equal(expected, AudioPlaybackService.ShouldRestore(position, duration));
}
