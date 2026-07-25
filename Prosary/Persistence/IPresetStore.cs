using Prosary.Models;

namespace Prosary.Persistence;

/// <summary>CRUD over saved <see cref="Prayer"/> favorites.</summary>
public interface IPresetStore
{
    Task<List<Prayer>> GetAllAsync();

    /// <summary>The default favorite for a given kind — first row with IsDefault set, else the
    /// first row of that kind, else null if there are none yet.</summary>
    Task<Prayer?> GetDefaultAsync(PrayerKind kind);

    Task<Prayer?> GetAsync(Guid id);

    /// <summary>Inserts or updates. If <paramref name="prayer"/> is default, clears IsDefault on
    /// every other favorite of the <em>same kind</em> only.</summary>
    Task SaveAsync(Prayer prayer);

    /// <summary>Deletes, promoting another same-kind favorite to default if the deleted one was
    /// the default and any remain.</summary>
    Task DeleteAsync(Prayer prayer);
}
