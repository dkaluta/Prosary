using Microsoft.UI.Dispatching;
using Prosary.ViewModels;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Media.SpeechSynthesis;

namespace Prosary.Services;

/// <summary>Reads original prayer text with an installed voice of the same language. A missing
/// Latin/Aramaic or other voice is an unavailable action, never a change of spoken language.</summary>
public sealed class PrayerSpeechService
{
    private static readonly Dictionary<IPrayerStepFlowViewModel, PrayerSpeechService> Active = [];
    private readonly DispatcherQueue _dispatcher = DispatcherQueue.GetForCurrentThread();
    private SpeechSynthesizer? _synthesizer;
    private SpeechSynthesisStream? _stream;
    private MediaPlayer? _player;
    private IPrayerStepFlowViewModel? _owner;
    private int _generation;
    public bool IsSpeaking { get; private set; }
    public bool Failed { get; private set; }
    public event Action? StateChanged;
    public static event Action<IPrayerStepFlowViewModel>? SpeakingChanged;

    public static bool IsSpeakingFor(IPrayerStepFlowViewModel owner) => Active.ContainsKey(owner);
    public static void StopFor(IPrayerStepFlowViewModel owner)
    {
        if (Active.TryGetValue(owner, out var speech)) speech.Stop();
    }

    public static string BaseLanguage(string code)
    {
        var language = code.Replace('_', '-').ToLowerInvariant().Split('-')[0];
        return language == "iw" ? "he" : language == "fil" ? "tl" : language;
    }
    public static bool VoiceMatches(string voiceLanguage, string prayerLanguage) =>
        !string.IsNullOrEmpty(BaseLanguage(prayerLanguage)) && BaseLanguage(voiceLanguage) == BaseLanguage(prayerLanguage);
    public static string SpokenText(string text) => text.Replace("**", string.Empty).Trim();

    public async Task<bool> SpeakAsync(IPrayerStepFlowViewModel owner)
    {
        Stop();
        Failed = false;
        var generation = ++_generation;
        try
        {
            var voice = SpeechSynthesizer.AllVoices
                .Where(v => VoiceMatches(v.Language, owner.SpeechLanguageCode))
                .OrderByDescending(v => v.Language.Equals(System.Globalization.CultureInfo.CurrentCulture.Name,
                    StringComparison.OrdinalIgnoreCase)).FirstOrDefault();
            var text = SpokenText(owner.SpeechBody);
            if (voice is null || string.IsNullOrEmpty(text)) return false;
            StopFor(owner);
            _synthesizer = new SpeechSynthesizer { Voice = voice };
            _owner = owner;
            Active[owner] = this;
            IsSpeaking = true;
            StateChanged?.Invoke();
            SpeakingChanged?.Invoke(owner);
            var stream = await _synthesizer.SynthesizeTextToStreamAsync(text);
            if (generation != _generation)
            {
                stream.Dispose();
                return true;
            }
            _stream = stream;
            _player = new MediaPlayer { AudioCategory = MediaPlayerAudioCategory.Speech,
                Source = MediaSource.CreateFromStream(stream, stream.ContentType) };
            _player.MediaEnded += (_, _) => _dispatcher.TryEnqueue(() =>
            {
                if (generation == _generation) Stop();
            });
            _player.MediaFailed += (_, _) => _dispatcher.TryEnqueue(() =>
            {
                if (generation == _generation)
                {
                    Failed = true;
                    Stop();
                }
            });
            _player.Play();
            return true;
        }
        catch
        {
            if (generation != _generation) return true;
            Failed = true;
            Stop();
            return false;
        }
    }

    public void Stop()
    {
        ++_generation;
        var previousOwner = _owner;
        if (_owner is { } owner) Active.Remove(owner);
        _owner = null;
        _player?.Pause();
        _player?.Dispose();
        _player = null;
        _stream?.Dispose();
        _stream = null;
        _synthesizer?.Dispose();
        _synthesizer = null;
        IsSpeaking = false;
        StateChanged?.Invoke();
        if (previousOwner is { } previous) SpeakingChanged?.Invoke(previous);
    }
}
