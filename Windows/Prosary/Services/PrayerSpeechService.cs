using System.Text.RegularExpressions;
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

    public static string NormalizeHebrewSpeech(string text)
    {
        const string diacritics = @"[\u0591-\u05bd\u05bf-\u05c2\u05c4\u05c5\u05c7]*";
        var divine = $@"(?:י{diacritics}ה{diacritics}ו{diacritics}ה{diacritics}|ה{diacritics}[׳\u0027]|י{diacritics}י{diacritics})";
        var adonai = $@"א{diacritics}ד{diacritics}נָ?{diacritics}[יי]{diacritics}";
        var prefix = $@"([בלמכשו]{diacritics})";
        const string boundary = @"(?:^|[^\u0591-\u05bd\u05bf-\u05c2\u05c4-\u05c5\u05c7\u05d0-\u05ea])";
        const string lookahead = @"(?=$|[^\u0591-\u05bd\u05bf-\u05c2\u05c4-\u05c5\u05c7\u05d0-\u05ea])";

        var elohimPattern = $@"({boundary})(\S*{adonai}\S*)(\s+){prefix}?{divine}{lookahead}";
        var result = Regex.Replace(text, elohimPattern, match =>
        {
            var pre = match.Groups[1].Value;
            var adonaiWord = match.Groups[2].Value;
            var between = match.Groups[3].Value;
            string elohim;
            if (match.Groups[4].Success && match.Groups[4].Length > 0)
            {
                var first = match.Groups[4].Value[0];
                var p = first switch
                {
                    'ו' => "וֵ",
                    'ל' => "לֵ",
                    'ב' => "בֵּ",
                    'מ' => "מֵ",
                    _ => first.ToString()
                };
                elohim = $"{p}אלֹהִים";
            }
            else
            {
                elohim = "אֱלֹהִים";
            }
            return $"{pre}{adonaiWord}{between}{elohim}";
        });

        var divinePattern = $@"({boundary}){prefix}?{divine}{lookahead}";
        result = Regex.Replace(result, divinePattern, match =>
        {
            var pre = match.Groups[1].Value;
            string word;
            if (match.Groups[2].Success && match.Groups[2].Length > 0)
            {
                var first = match.Groups[2].Value[0];
                word = first switch
                {
                    'ל' => "לַאדֹנָי",
                    'ב' => "בַּאדֹנָי",
                    'ו' => "וַאדֹנָי",
                    'מ' => "מֵאדֹנָי",
                    'כ' => "כַּאדֹנָי",
                    'ש' => "שֶׁאֲדֹנָי",
                    _ => $"{first}אֲדֹנָי"
                };
            }
            else
            {
                word = "אֲדֹנָי";
            }
            return $"{pre}{word}";
        });

        return result;
    }

    public static string SpokenText(string text, string? languageCode = null)
    {
        var body = text.Replace("**", string.Empty).Trim();
        var isHebrew = languageCode != null
            ? BaseLanguage(languageCode) == "he"
            : body.Any(c => c >= '\u0590' && c <= '\u05FF');
        if (isHebrew)
        {
            body = NormalizeHebrewSpeech(body);
        }
        return body;
    }

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
            var text = SpokenText(owner.SpeechBody, owner.SpeechLanguageCode);
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
