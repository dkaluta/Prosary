using Microsoft.UI.Dispatching;
using Prosary.Localization;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Storage;

namespace Prosary.Services;

/// <summary>
/// Plays one bundle audio track (see Shared/ARCHITECTURE.md "Audio"): extracts the Ogg Opus
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
            StateChanged?.Invoke();
        });
        player.MediaEnded += (_, _) => OnUi(() =>
        {
            IsPlaying = false;
            CurrentTime = Duration;
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
        CurrentTime = 0;
        Duration = 0; // real value arrives with MediaOpened
        StateChanged?.Invoke();
    }

    /// <summary>The cached audio file for a track, extracted from the pack on first use.</summary>
    private static string? ExtractedFilePath(string bundleId, DevotionAudioTrack track)
    {
        try
        {
            var dir = Path.Combine(ApplicationData.Current.LocalCacheFolder.Path, "PrayerAudio", bundleId);
            var path = Path.Combine(dir, Path.GetFileName(track.File));
            if (new FileInfo(path) is { Exists: true, Length: > 0 })
            {
                return path;
            }

            var data = PrayerPackStore.AudioData(bundleId, track.File);
            if (data is null)
            {
                return null;
            }

            Directory.CreateDirectory(dir);
            File.WriteAllBytes(path, data);
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
        _player?.Dispose();
        _player = null;
        Track = null;
        IsPlaying = false;
        CurrentTime = 0;
        Duration = 0;
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
