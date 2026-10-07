namespace Prosary.Models;

/// <summary>Finds the first step of the preceding/following Rosary mystery without disturbing
/// the ordinary bead-by-bead Back/Next controls. A Next target equal to steps.Count finishes
/// the session when the final mystery has no closing prayers.</summary>
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
            // Opening material advances to the first mystery. Closing material has no next
            // mystery; the ordinary Next button still advances its individual prayers.
            return steps.Skip(currentIndex + 1)
                .Select((step, offset) => (step, index: currentIndex + 1 + offset))
                .Where(pair => pair.step.DecadeIndex.HasValue)
                .Select(pair => (int?)pair.index)
                .FirstOrDefault();
        }

        return steps.Skip(currentIndex + 1)
            .Select((step, offset) => (step, index: currentIndex + 1 + offset))
            .Where(pair => pair.step.DecadeIndex is null || pair.step.DecadeIndex > currentDecade.Value)
            .Select(pair => (int?)pair.index)
            .FirstOrDefault() ?? steps.Count;
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
