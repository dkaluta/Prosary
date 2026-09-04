using Microsoft.UI.Dispatching;
using Prosary.Localization;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Storage;

namespace Prosary.Services;

/// <summary>
/// Plays one bundle audio track (see Shared/ARCHITECTURE.markdown "Audio"): extracts the Ogg Opus
/// bytes from the pack into the local cache folder (recordings dwarf every other bundle asset,
/// so they are never held in memory) and plays them with <see cref="MediaPlayer"/> — Media
/// Foundation demuxes Ogg Opus where the Web Media Extensions codecs are present (preinstalled
/// on most systems); where they aren't, <see cref="MediaPlayer.MediaFailed"/> fires and the
/// ViewModel simply hides its audio bar. The Windows mirror of iOS's AudioPlaybackController.
/// Chapter → step syncing lives in the ViewModel, because only it knows the built step sequence
/// the chapters' advisory StepIndex hints point into.
///
/// MediaPlayer's events arrive off the UI thread, so every callback marshals through the
/// <see cref="DispatcherQueue"/> captured at construction — construct on the UI thread.
/// </summary>
public sealed class AudioPlaybackService : IDisposable
{
    private readonly DispatcherQueue _dispatcher = DispatcherQueue.GetForCurrentThread();
    private MediaPlayer? _player;

    public DevotionAudioTrack? Track { get; private set; }

    public bool IsLoaded => _player is not null;

    public bool IsPlaying { get; private set; }

    /// <summary>True when <see cref="Load"/> resumed a previous session's position (applied at
    /// MediaOpened, when the real duration arrives). The ViewModel's state handler then pulls
    /// the page to the restored chapter through the ordinary chapter→step hint path.</summary>
    public bool DidRestorePosition { get; private set; }

    /// <summary>Seconds, mirrored from the playback session on its position ticks.</summary>
    public double CurrentTime { get; private set; }

    public double Duration { get; private set; }

    /// <summary>Raised on the UI thread whenever playback state or position changes — the
    /// ViewModel copies whatever it displays out of the properties above.</summary>
    public event Action? StateChanged;

    /// <summary>Index into the track's chapters of the chapter <see cref="CurrentTime"/> falls
    /// in; null while nothing is loaded.</summary>
    public int? CurrentChapterIndex =>
        Track?.Chapters is { } chapters ? ChapterIndexFor(chapters, CurrentTime) : null;

    /// <summary>Extracts and opens the track; leaves the player paused at 0. Any previous track
    /// stops. A demux/codec failure surfaces as a later <see cref="Stop"/> (bar disappears)
    /// rather than an exception.</summary>
    public void Load(string bundleId, DevotionAudioTrack track)
    {
        Stop();
        var file = ExtractedFilePath(bundleId, track);
        if (file is null)
        {
            return;
        }

        var player = new MediaPlayer
        {
            AudioCategory = MediaPlayerAudioCategory.Speech,
            Source = MediaSource.CreateFromUri(new Uri(file)),
        };
        player.MediaOpened += (_, _) => OnUi(() =>
        {
            Duration = player.PlaybackSession.NaturalDuration.TotalSeconds;
            // Resume where the last session left off (positions persist per track id).
            var saved = ReadSavedPosition();
            if (ShouldRestore(saved, Duration))
            {
                DidRestorePosition = true;
                player.PlaybackSession.Position = TimeSpan.FromSeconds(saved);
                CurrentTime = saved;
            }

            StateChanged?.Invoke();
        });
        player.MediaEnded += (_, _) => OnUi(() =>
        {
            IsPlaying = false;
            CurrentTime = Duration;
            SavePosition(); // at the duration this clears the key — a finished listen restarts fresh
            StateChanged?.Invoke();
        });
        // No Ogg Opus demuxer on this machine (Web Media Extensions absent) or a corrupt file —
        // drop back to the no-audio experience instead of a dead bar.
        player.MediaFailed += (_, _) => OnUi(Stop);
        player.PlaybackSession.PositionChanged += (session, _) => OnUi(() =>
        {
            CurrentTime = session.Position.TotalSeconds;
            StateChanged?.Invoke();
        });

        _player = player;
        Track = track;
        _positionKey = $"audioPosition.{bundleId}.{track.Id}";
        CurrentTime = 0;
        Duration = 0; // real value arrives with MediaOpened (which also restores the position)
        StateChanged?.Invoke();
    }

    private string? _positionKey;

    private double ReadSavedPosition()
    {
        try
        {
            return _positionKey is { } key
                && ApplicationData.Current.LocalSettings.Values.TryGetValue(key, out var value)
                && value is double seconds ? seconds : 0;
        }
        catch
        {
            return 0;
        }
    }

    /// <summary>Persists the position (or clears it near the edges, so finished and
    /// abandoned-at-start sessions begin fresh next time). Called on pause, stop, and
    /// natural end.</summary>
    private void SavePosition()
    {
        if (_positionKey is not { } key)
        {
            return;
        }

        try
        {
            if (ShouldRestore(CurrentTime, Duration))
            {
                ApplicationData.Current.LocalSettings.Values[key] = CurrentTime;
            }
            else
            {
                ApplicationData.Current.LocalSettings.Values.Remove(key);
            }
        }
        catch
        {
            // Settings I/O never breaks playback.
        }
    }

    /// <summary>A stored position worth resuming: past the first moments, short of the last
    /// stretch — the same rule on all three platforms.</summary>
    public static bool ShouldRestore(double position, double duration) =>
        position > 10 && duration > 0 && position < duration * 0.9;

    /// <summary>The cached audio file for a track, extracted from the pack on first use.</summary>
    private static string? ExtractedFilePath(string bundleId, DevotionAudioTrack track)
    {
        try
        {
            var dir = Path.Combine(ApplicationData.Current.LocalCacheFolder.Path, "PrayerAudio", bundleId);
            var cacheKey = PrayerPackStore.AudioCacheKey(bundleId, track.File);
            if (cacheKey is null)
            {
                return null;
            }

            var sourceName = Path.GetFileName(track.File);
            var sourceStem = Path.GetFileNameWithoutExtension(sourceName);
            var cacheName = $"{sourceStem}--{cacheKey}{Path.GetExtension(sourceName)}";
            var path = Path.Combine(dir, cacheName);
            if (new FileInfo(path) is { Exists: true, Length: > 0 })
            {
                return path;
            }

            Directory.CreateDirectory(dir);
            if (!PrayerPackStore.ExtractAudioFile(bundleId, track.File, path))
            {
                return null;
            }

            foreach (var cached in Directory.EnumerateFiles(dir))
            {
                var name = Path.GetFileName(cached);
                var stem = Path.GetFileNameWithoutExtension(name);
                var isLegacy = name == sourceName;
                var isOlderRevision = stem.StartsWith($"{sourceStem}--", StringComparison.Ordinal)
                    && stem != Path.GetFileNameWithoutExtension(cacheName);
                if (!isLegacy && !isOlderRevision) continue;
                try
                {
                    File.Delete(cached);
                }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException)
                {
                    // A player may still hold the prior revision. It is unreachable as a cache
                    // hit and LocalCacheFolder remains disposable, so cleanup can wait.
                    System.Diagnostics.Debug.WriteLine($"[AudioPlaybackService] old cache cleanup failed: {error}");
                }
            }

            return path;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[AudioPlaybackService] extract failed: {ex}");
            return null;
        }
    }

    public void PlayPause()
    {
        if (_player is not { } player)
        {
            return;
        }

        if (IsPlaying)
        {
            player.Pause();
            IsPlaying = false;
            SavePosition();
        }
        else
        {
            // Finished-and-restarted: play at the end starts over instead of doing nothing.
            if (Duration > 0 && CurrentTime >= Duration - 0.05)
            {
                player.PlaybackSession.Position = TimeSpan.Zero;
                CurrentTime = 0;
            }

            player.Play();
            IsPlaying = true;
        }

        StateChanged?.Invoke();
    }

    public void Seek(double seconds)
    {
        if (_player is not { } player)
        {
            return;
        }

        var clamped = Math.Clamp(seconds, 0, Duration > 0 ? Duration : seconds);
        player.PlaybackSession.Position = TimeSpan.FromSeconds(clamped);
        CurrentTime = clamped;
        StateChanged?.Invoke();
    }

    public void SeekToChapter(int index)
    {
        if (Track?.Chapters is { } chapters && index >= 0 && index < chapters.Count)
        {
            Seek(chapters[index].Start);
        }
    }

    /// <summary>Back within a chapter's first moments goes to the previous chapter (the
    /// audiobook convention); later in a chapter it restarts the chapter.</summary>
    public void PreviousChapter()
    {
        if (Track?.Chapters is { } chapters && CurrentChapterIndex is { } index)
        {
            SeekToChapter(PreviousChapterTarget(chapters, index, CurrentTime));
        }
    }

    public void NextChapter()
    {
        if (Track?.Chapters is { } chapters && CurrentChapterIndex is { } index && index + 1 < chapters.Count)
        {
            SeekToChapter(index + 1);
        }
    }

    public void Stop()
    {
        if (_player is not null)
        {
            SavePosition();
        }

        _player?.Dispose();
        _player = null;
        Track = null;
        IsPlaying = false;
        CurrentTime = 0;
        Duration = 0;
        DidRestorePosition = false;
        _positionKey = null;
        StateChanged?.Invoke();
    }

    public void Dispose() => Stop();

    private void OnUi(Action action)
    {
        if (_dispatcher.HasThreadAccess)
        {
            action();
        }
        else
        {
            _dispatcher.TryEnqueue(() => action());
        }
    }

    /// <summary>Pure chapter math (mirrors iOS/Android): the chapter a time falls in, with a
    /// hair of tolerance so landing exactly on a boundary via SeekToChapter counts as inside.</summary>
    public static int? ChapterIndexFor(IReadOnlyList<DevotionAudioTrack.Chapter> chapters, double time)
    {
        if (chapters.Count == 0)
        {
            return null;
        }

        for (var i = chapters.Count - 1; i >= 0; i--)
        {
            if (chapters[i].Start <= time + 0.01)
            {
                return i;
            }
        }

        return 0;
    }

    public static int PreviousChapterTarget(
        IReadOnlyList<DevotionAudioTrack.Chapter> chapters, int currentIndex, double time)
    {
        var restartThreshold = chapters[currentIndex].Start + 2;
        return time < restartThreshold ? Math.Max(currentIndex - 1, 0) : currentIndex;
    }
}
