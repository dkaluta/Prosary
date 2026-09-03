namespace Prosary.Models;

/// <summary>Finds the first step of the preceding/following Rosary mystery without disturbing
/// the ordinary bead-by-bead Back/Next controls.</summary>
public static class MysteryStepNavigation
{
    public static int? Previous(IReadOnlyList<RosaryStep> steps, int currentIndex)
    {
        if (steps.Count == 0 || currentIndex < 0 || currentIndex >= steps.Count)
        {
            return null;
        }

        var currentDecade = steps[currentIndex].DecadeIndex;
        var distinct = steps.Where(step => step.DecadeIndex.HasValue)
            .Select(step => step.DecadeIndex!.Value)
            .Distinct()
            .ToList();
        if (distinct.Count == 0)
        {
            return null;
        }

        int targetDecade;
        if (currentDecade is { } decade)
        {
            var position = distinct.IndexOf(decade);
            if (position <= 0) return null;
            targetDecade = distinct[position - 1];
        }
        else
        {
            // A non-mystery step after the final mystery (antiphon, intentions, cross) returns
            // to the last one; opening steps have no previous mystery.
            var nearestEarlier = steps.Take(currentIndex).Reverse()
                .Select(step => step.DecadeIndex)
                .FirstOrDefault(value => value.HasValue);
            if (nearestEarlier is null) return null;
            targetDecade = nearestEarlier.Value;
        }

        return FirstIndex(steps, targetDecade);
    }

    public static int? Next(IReadOnlyList<RosaryStep> steps, int currentIndex)
    {
        if (steps.Count == 0 || currentIndex < 0 || currentIndex >= steps.Count)
        {
            return null;
        }

        var currentDecade = steps[currentIndex].DecadeIndex;
        if (currentDecade is null)
        {
            // Opening material advances to the first mystery. Once every mystery is behind us,
            // there is no next mystery even though closing prayers remain.
            return steps.Skip(currentIndex + 1)
                .Select((step, offset) => (step, index: currentIndex + 1 + offset))
                .Where(pair => pair.step.DecadeIndex.HasValue)
                .Select(pair => (int?)pair.index)
                .FirstOrDefault();
        }

        return steps.Skip(currentIndex + 1)
            .Select((step, offset) => (step, index: currentIndex + 1 + offset))
            .Where(pair => pair.step.DecadeIndex is { } decade && decade > currentDecade.Value)
            .Select(pair => (int?)pair.index)
            .FirstOrDefault();
    }

    private static int? FirstIndex(IReadOnlyList<RosaryStep> steps, int decade)
    {
        for (var index = 0; index < steps.Count; index++)
        {
            if (steps[index].DecadeIndex == decade) return index;
        }
        return null;
    }
}
