using System.Runtime.InteropServices;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class TodayReminderSchedulerTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void UnavailableNotificationServiceDoesNotPreventRefresh(bool comFailure)
    {
        TodayReminderScheduler.Refresh(() =>
        {
            if (comFailure) throw new COMException("Toast registration unavailable.");
            throw new InvalidOperationException("No package identity.");
        });
    }

    [Fact]
    public void DisabledRemindersStillAttemptToRemoveExistingDeliveries()
    {
        var readingsEnabled = AppSettings.ReadingsReminderEnabled;
        var saintsEnabled = AppSettings.SaintReminderEnabled;
        try
        {
            AppSettings.SetReadingsReminderEnabled(false);
            AppSettings.SetSaintReminderEnabled(false);
            var attempts = 0;
            TodayReminderScheduler.Refresh(() =>
            {
                attempts++;
                throw new COMException("Toast registration unavailable.");
            });
            Assert.Equal(1, attempts);
        }
        finally
        {
            AppSettings.SetReadingsReminderEnabled(readingsEnabled);
            AppSettings.SetSaintReminderEnabled(saintsEnabled);
        }
    }

    [Fact]
    public void UnexpectedFailuresRemainVisible()
    {
        Assert.Throws<ArgumentException>(() =>
            TodayReminderScheduler.Refresh(() => throw new ArgumentException("Invalid scheduling data.")));
    }
}
