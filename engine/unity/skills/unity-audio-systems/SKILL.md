# Unity Audio Systems

Reference guide for audio in Unity. Covers AudioSource, AudioMixer, spatial audio,
pooling, music systems, import settings, and common architecture patterns.

## Core Components

### AudioSource

The component that plays audio clips. Attach to any GameObject.

| Property | Purpose | Typical Value |
|----------|---------|---------------|
| Clip | The AudioClip to play | Assign in Inspector or code |
| Volume | Loudness (0-1) | 0.5 - 1.0 |
| Pitch | Playback speed/pitch (1 = normal) | 0.8 - 1.2 for variation |
| Spatial Blend | 0 = 2D (full stereo), 1 = 3D (positional) | 0 for UI/music, 1 for world SFX |
| Play On Awake | Auto-play when enabled | true for ambience, false for SFX |
| Loop | Repeat continuously | true for music/ambience |
| Output | AudioMixer group to route to | SFX, Music, Ambient group |
| Priority | 0 = highest, 256 = lowest | 128 default; 0 for music, 128+ for SFX |

### Playing Audio

```csharp
public class SoundPlayer : MonoBehaviour
{
    [SerializeField] AudioSource _source;
    [SerializeField] AudioClip _fireClip;
    [SerializeField] AudioClip[] _footstepClips;

    // Play(): replaces current clip, only one at a time
    public void PlayMusic(AudioClip clip)
    {
        _source.clip = clip;
        _source.Play();
    }

    // PlayOneShot(): overlaps with current playback, fire-and-forget
    public void PlayFireSound()
    {
        _source.PlayOneShot(_fireClip, 0.8f); // volume scale
    }

    // Random selection for variety
    public void PlayFootstep()
    {
        AudioClip clip = _footstepClips[Random.Range(0, _footstepClips.Length)];
        _source.PlayOneShot(clip);
    }

    // Play at a world position (creates temporary AudioSource)
    public void PlayExplosionAt(Vector3 position)
    {
        AudioSource.PlayClipAtPoint(_fireClip, position, 1f);
    }
}
```

### AudioListener

One per scene, on the object that "hears" the world. Typically the main camera.

```csharp
// Only one AudioListener can be active. Disable extras:
void Awake()
{
    AudioListener[] listeners = FindObjectsByType<AudioListener>(FindObjectsSortMode.None);
    if (listeners.Length > 1)
        Debug.LogWarning("Multiple AudioListeners found!");
}
```

## AudioMixer

Central routing and effects hub. Create via **Assets > Create > Audio Mixer**.

### Group Hierarchy

```
Master
  +-- Music
  +-- SFX
  |     +-- Weapons
  |     +-- Footsteps
  |     +-- UI
  +-- Ambient
  |     +-- Wind
  |     +-- Rain
  +-- Voice
```

### Exposed Parameters

Right-click any parameter in the Mixer Inspector and select **Expose to Script**:

```csharp
public class AudioSettings : MonoBehaviour
{
    [SerializeField] AudioMixer _mixer;

    // Volume uses logarithmic scale: -80dB (silent) to 0dB (full)
    // Convert linear 0-1 to dB:
    public void SetMasterVolume(float linearVolume)
    {
        float dB = linearVolume > 0.0001f
            ? Mathf.Log10(linearVolume) * 20f
            : -80f;
        _mixer.SetFloat("MasterVolume", dB);
    }

    public float GetMasterVolume()
    {
        _mixer.GetFloat("MasterVolume", out float dB);
        return Mathf.Pow(10f, dB / 20f); // dB back to linear
    }

    // Save/load with PlayerPrefs
    public void SaveVolumes()
    {
        _mixer.GetFloat("MasterVolume", out float master);
        _mixer.GetFloat("MusicVolume", out float music);
        _mixer.GetFloat("SFXVolume", out float sfx);
        PlayerPrefs.SetFloat("MasterVol", master);
        PlayerPrefs.SetFloat("MusicVol", music);
        PlayerPrefs.SetFloat("SFXVol", sfx);
    }

    public void LoadVolumes()
    {
        _mixer.SetFloat("MasterVolume", PlayerPrefs.GetFloat("MasterVol", 0f));
        _mixer.SetFloat("MusicVolume", PlayerPrefs.GetFloat("MusicVol", 0f));
        _mixer.SetFloat("SFXVolume", PlayerPrefs.GetFloat("SFXVol", 0f));
    }
}
```

### Mixer Effects

Add effects to groups via the Mixer Inspector:

| Effect | Purpose | Use On |
|--------|---------|--------|
| Lowpass Filter | Muffle sound (underwater, behind walls) | SFX, Master |
| Highpass Filter | Remove bass | Radio effect |
| Reverb | Room reflections | SFX (cave, hallway) |
| Compressor | Normalize loud/quiet | Master |
| Echo | Delayed repeats | SFX (canyon) |
| Chorus | Thicken sound | Music, Voice |

## Mixer Snapshots

Snapshots save and restore all mixer parameter states. Use for environmental transitions:

```csharp
public class AmbientZoneController : MonoBehaviour
{
    [SerializeField] AudioMixerSnapshot _outdoorSnapshot;
    [SerializeField] AudioMixerSnapshot _indoorSnapshot;
    [SerializeField] AudioMixerSnapshot _underwaterSnapshot;

    public void TransitionToIndoor()
    {
        _indoorSnapshot.TransitionTo(1.5f); // Blend over 1.5 seconds
    }

    public void TransitionToOutdoor()
    {
        _outdoorSnapshot.TransitionTo(1.0f);
    }

    // Weighted blend between multiple snapshots
    public void BlendSnapshots(float indoorWeight)
    {
        AudioMixerSnapshot[] snapshots = { _outdoorSnapshot, _indoorSnapshot };
        float[] weights = { 1f - indoorWeight, indoorWeight };
        _outdoorSnapshot.audioMixer.TransitionToSnapshots(snapshots, weights, 0.5f);
    }
}
```

### Snapshot Parameters for Common Scenarios

| Scenario | Lowpass (Hz) | Reverb Send | Music Vol | SFX Vol |
|----------|-------------|-------------|-----------|---------|
| Outdoor | 22000 | -10dB | 0dB | 0dB |
| Indoor | 5000 | -2dB | -3dB | 0dB |
| Underwater | 800 | 0dB | -10dB | -5dB |
| Paused | 1500 | -5dB | -6dB | -20dB |

## Spatial Audio (3D Sound)

### 3D Sound Settings

On AudioSource, set **Spatial Blend = 1** for full 3D positioning:

| Setting | Purpose | Default |
|---------|---------|---------|
| Doppler Level | Pitch shift from velocity | 1 (reduce for less effect) |
| Spread | Angular spread (0 = point, 360 = omnidirectional) | 0 |
| Min Distance | Full volume within this radius | 1 |
| Max Distance | Inaudible beyond this radius | 500 |
| Rolloff Mode | How volume decreases with distance | Logarithmic |

### Rolloff Modes

| Mode | Behavior | Use For |
|------|----------|---------|
| Logarithmic | Realistic decay (most natural) | Outdoor sounds, gunfire |
| Linear | Constant decay rate | Predictable falloff, UI feedback |
| Custom | User-defined curve | Specialized effects (alarm zones) |

```csharp
// Setting 3D properties in code
AudioSource src = gameObject.AddComponent<AudioSource>();
src.spatialBlend = 1f;
src.rolloffMode = AudioRolloffMode.Logarithmic;
src.minDistance = 2f;
src.maxDistance = 50f;
src.dopplerLevel = 0.5f;
```

### Reverb Zones

Add `AudioReverbZone` to trigger volumes for room-specific reverb:

```
AudioReverbZone:
  Min Distance: 5
  Max Distance: 20
  Reverb Preset: Cave / Hallway / Bathroom / Arena
```

## Audio Pooling

Reuse AudioSources for frequent, overlapping sounds:

```csharp
public class AudioPool : MonoBehaviour
{
    [SerializeField] int _poolSize = 16;
    AudioSource[] _pool;
    int _nextIndex;

    void Awake()
    {
        _pool = new AudioSource[_poolSize];
        for (int i = 0; i < _poolSize; i++)
        {
            GameObject go = new GameObject($"PooledAudio_{i}");
            go.transform.SetParent(transform);
            _pool[i] = go.AddComponent<AudioSource>();
            _pool[i].playOnAwake = false;
            _pool[i].spatialBlend = 1f;
        }
    }

    public AudioSource Play(AudioClip clip, Vector3 position,
        float volume = 1f, float pitch = 1f)
    {
        AudioSource src = _pool[_nextIndex];
        _nextIndex = (_nextIndex + 1) % _poolSize;

        src.transform.position = position;
        src.clip = clip;
        src.volume = volume;
        src.pitch = pitch;
        src.Play();
        return src;
    }

    public void PlayRandomPitch(AudioClip clip, Vector3 position,
        float volume = 1f, float pitchMin = 0.9f, float pitchMax = 1.1f)
    {
        Play(clip, position, volume, Random.Range(pitchMin, pitchMax));
    }
}
```

## Music System

### Cross-Fade Between Tracks

```csharp
public class MusicManager : MonoBehaviour
{
    [SerializeField] AudioSource _sourceA;
    [SerializeField] AudioSource _sourceB;
    [SerializeField] float _crossFadeDuration = 2f;

    AudioSource _activeSource;
    Coroutine _fadeCoroutine;

    void Awake()
    {
        _activeSource = _sourceA;
    }

    public void PlayTrack(AudioClip clip)
    {
        AudioSource incoming = _activeSource == _sourceA ? _sourceB : _sourceA;
        incoming.clip = clip;
        incoming.volume = 0f;
        incoming.Play();

        if (_fadeCoroutine != null) StopCoroutine(_fadeCoroutine);
        _fadeCoroutine = StartCoroutine(CrossFade(_activeSource, incoming));
        _activeSource = incoming;
    }

    IEnumerator CrossFade(AudioSource outgoing, AudioSource incoming)
    {
        float elapsed = 0f;
        float outStartVol = outgoing.volume;

        while (elapsed < _crossFadeDuration)
        {
            elapsed += Time.unscaledDeltaTime; // Unscaled so it works when paused
            float t = elapsed / _crossFadeDuration;
            incoming.volume = Mathf.Lerp(0f, 1f, t);
            outgoing.volume = Mathf.Lerp(outStartVol, 0f, t);
            yield return null;
        }

        outgoing.Stop();
        outgoing.volume = 0f;
        incoming.volume = 1f;
    }
}
```

### Playlist Management

```csharp
public class Playlist : MonoBehaviour
{
    [SerializeField] AudioClip[] _tracks;
    [SerializeField] bool _shuffle;
    [SerializeField] MusicManager _musicManager;

    int _currentIndex = -1;
    List<int> _playOrder;

    void Start()
    {
        BuildPlayOrder();
        PlayNext();
    }

    void Update()
    {
        // Check if current track is about to end, queue next
        if (!_musicManager.IsPlaying && _tracks.Length > 0)
            PlayNext();
    }

    void PlayNext()
    {
        _currentIndex = (_currentIndex + 1) % _playOrder.Count;
        if (_currentIndex == 0 && _shuffle) ShuffleOrder();
        _musicManager.PlayTrack(_tracks[_playOrder[_currentIndex]]);
    }

    void BuildPlayOrder()
    {
        _playOrder = Enumerable.Range(0, _tracks.Length).ToList();
        if (_shuffle) ShuffleOrder();
    }

    void ShuffleOrder()
    {
        for (int i = _playOrder.Count - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            (_playOrder[i], _playOrder[j]) = (_playOrder[j], _playOrder[i]);
        }
    }
}
```

## AudioClip Import Settings

### Load Type

| Load Type | When to Use | Memory | CPU |
|-----------|------------|--------|-----|
| Decompress On Load | Short, frequent SFX (footsteps, hits) | High (uncompressed in memory) | Low at play time |
| Compressed In Memory | Medium clips, less frequent | Medium | Medium (decompresses on play) |
| Streaming | Long clips (music, ambience) | Low (streams from disk) | Continuous disk I/O |

### Compression Format

| Format | Quality | Size | Use For |
|--------|---------|------|---------|
| Vorbis | Adjustable (0-100%) | Small | Music, long ambience |
| ADPCM | Fixed, slightly lossy | Medium | Short SFX, frequent playback |
| PCM | Lossless | Large | Only when quality is critical |

### Best Practices

| Clip Type | Force Mono | Load Type | Compression | Quality |
|-----------|-----------|-----------|-------------|---------|
| Footsteps | Yes | Decompress On Load | ADPCM | - |
| Gunfire | Yes | Decompress On Load | ADPCM | - |
| Music | No (stereo) | Streaming | Vorbis | 70-80% |
| Ambience loops | No | Streaming | Vorbis | 60-70% |
| UI clicks | Yes | Decompress On Load | ADPCM | - |
| Voice lines | Yes | Compressed In Memory | Vorbis | 80% |

**Force Mono:** Always for SFX that plays in 3D -- stereo is meaningless for spatialized sound and doubles memory.

## Ambient Zones

Trigger-based audio region switching:

```csharp
[RequireComponent(typeof(Collider))]
public class AmbientZone : MonoBehaviour
{
    [SerializeField] AudioClip _ambientLoop;
    [SerializeField] AudioMixerSnapshot _zoneSnapshot;
    [SerializeField] float _transitionTime = 1.5f;
    [SerializeField] float _volume = 0.6f;

    AudioSource _source;

    void Awake()
    {
        _source = gameObject.AddComponent<AudioSource>();
        _source.clip = _ambientLoop;
        _source.loop = true;
        _source.volume = 0f;
        _source.spatialBlend = 0f; // 2D -- ambient is everywhere
        _source.playOnAwake = false;
    }

    void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag("Player")) return;
        _source.Play();
        StartCoroutine(FadeIn());
        _zoneSnapshot?.TransitionTo(_transitionTime);
    }

    void OnTriggerExit(Collider other)
    {
        if (!other.CompareTag("Player")) return;
        StartCoroutine(FadeOut());
    }

    IEnumerator FadeIn()
    {
        while (_source.volume < _volume)
        {
            _source.volume += Time.deltaTime / _transitionTime;
            yield return null;
        }
        _source.volume = _volume;
    }

    IEnumerator FadeOut()
    {
        while (_source.volume > 0f)
        {
            _source.volume -= Time.deltaTime / _transitionTime;
            yield return null;
        }
        _source.Stop();
    }
}
```

## Audio in Timeline

Add **Audio Track** to a Timeline:
1. Create Audio Track, bind to an AudioSource
2. Drag AudioClips onto the track at desired times
3. Adjust volume curves per clip in the Timeline editor
4. Clips can overlap for crossfades

```csharp
// The bound AudioSource handles playback automatically.
// For dynamic audio events, use Signal Track instead:
// Signal Track -> Signal Emitter -> SignalReceiver component -> method call
```

## Common Patterns

### Singleton AudioManager

```csharp
public class AudioManager : MonoBehaviour
{
    public static AudioManager Instance { get; private set; }

    [SerializeField] AudioMixer _mixer;
    [SerializeField] AudioPool _sfxPool;
    [SerializeField] MusicManager _music;

    // Sound library: map enum to clips
    [System.Serializable]
    public struct SoundEntry
    {
        public SoundId id;
        public AudioClip[] clips; // Multiple variants for randomization
        public float volume;
        public float pitchVariation;
    }

    [SerializeField] SoundEntry[] _sounds;
    Dictionary<SoundId, SoundEntry> _soundLookup;

    void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
        DontDestroyOnLoad(gameObject);

        _soundLookup = new Dictionary<SoundId, SoundEntry>();
        foreach (var entry in _sounds)
            _soundLookup[entry.id] = entry;
    }

    public void PlaySFX(SoundId id, Vector3 position)
    {
        if (!_soundLookup.TryGetValue(id, out SoundEntry entry)) return;
        AudioClip clip = entry.clips[Random.Range(0, entry.clips.Length)];
        float pitch = 1f + Random.Range(-entry.pitchVariation, entry.pitchVariation);
        _sfxPool.Play(clip, position, entry.volume, pitch);
    }

    public void PlayMusic(AudioClip clip) => _music.PlayTrack(clip);
    public void SetMasterVolume(float vol) => SetVolume("MasterVolume", vol);
    public void SetMusicVolume(float vol) => SetVolume("MusicVolume", vol);
    public void SetSFXVolume(float vol) => SetVolume("SFXVolume", vol);

    void SetVolume(string param, float linear)
    {
        float dB = linear > 0.0001f ? Mathf.Log10(linear) * 20f : -80f;
        _mixer.SetFloat(param, dB);
    }
}

public enum SoundId
{
    ButtonClick, ButtonHover,
    FootstepDirt, FootstepMetal, FootstepWood,
    GunFire, GunReload, GunEmpty,
    Explosion, ImpactLight, ImpactHeavy,
    PickupCoin, PickupHealth,
    PlayerHurt, PlayerDeath
}
```

### Random Pitch Variation

Prevents repetitive SFX from sounding mechanical:

```csharp
// On any AudioSource play call, vary pitch slightly
_source.pitch = Random.Range(0.92f, 1.08f);
_source.PlayOneShot(clip);
_source.pitch = 1f; // Reset for next play
```
