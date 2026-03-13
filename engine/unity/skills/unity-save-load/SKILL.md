# Unity Save/Load and Data Persistence

Patterns for saving game state, loading assets, and managing persistent data.

## PlayerPrefs — Simple Key-Value Storage

PlayerPrefs stores small amounts of data in OS-specific locations (registry on Windows, plist on macOS). Use for **settings only**, not game saves.

```csharp
// Writing
PlayerPrefs.SetInt("HighScore", 9999);
PlayerPrefs.SetFloat("MasterVolume", 0.8f);
PlayerPrefs.SetString("PlayerName", "Totes");
PlayerPrefs.Save(); // flush to disk (automatic on Application.Quit)

// Reading (with defaults)
int highScore = PlayerPrefs.GetInt("HighScore", 0);
float volume = PlayerPrefs.GetFloat("MasterVolume", 1.0f);
string name = PlayerPrefs.GetString("PlayerName", "Player");

// Checking existence
if (PlayerPrefs.HasKey("MasterVolume")) { /* ... */ }

// Deleting
PlayerPrefs.DeleteKey("MasterVolume");
PlayerPrefs.DeleteAll(); // nuclear option — settings reset
```

**Limitations:**
- Not secure (plain text in registry/plist)
- No structured data (no arrays, no objects)
- Platform-specific storage locations
- Do NOT use for save games — use JSON/binary files instead

## JSON Serialization

### JsonUtility (Built-in, Fast)

Unity's built-in JSON serializer. Fast but limited:

```csharp
[System.Serializable]
public class SaveData
{
    public string playerName;
    public int level;
    public float playTime;
    public Vector3 playerPosition; // Unity types work!
    public List<string> inventory; // Lists work
    public EquipmentData equipment; // Nested serializable classes work
}

[System.Serializable]
public class EquipmentData
{
    public string weaponId;
    public string armorId;
    public int weaponLevel;
}

// Serialize
var data = new SaveData
{
    playerName = "Totes",
    level = 5,
    playTime = 3600f,
    playerPosition = new Vector3(10, 0, 5),
    inventory = new List<string> { "sword", "shield", "potion" },
    equipment = new EquipmentData { weaponId = "sword_01", armorId = "armor_02", weaponLevel = 3 }
};

string json = JsonUtility.ToJson(data, prettyPrint: true);

// Deserialize
SaveData loaded = JsonUtility.FromJson<SaveData>(json);

// Overwrite existing object (useful for ScriptableObjects)
JsonUtility.FromJsonOverwrite(json, existingData);
```

**JsonUtility limitations:**
- No `Dictionary<K,V>` support
- No polymorphism (abstract/interface fields)
- `null` serializes as default values, not `null`
- No top-level arrays (wrap in a class)
- No custom converters
- Fields must be `public` or have `[SerializeField]`

### Newtonsoft.Json (Full-Featured)

Install via Package Manager: `com.unity.nuget.newtonsoft-json` or NuGet.

```csharp
using Newtonsoft.Json;

// Full Dictionary support
var settings = new Dictionary<string, object>
{
    ["volume"] = 0.8f,
    ["difficulty"] = "hard",
    ["controls"] = new Dictionary<string, string>
    {
        ["jump"] = "Space",
        ["shoot"] = "Mouse0"
    }
};

string json = JsonConvert.SerializeObject(settings, Formatting.Indented);
var loaded = JsonConvert.DeserializeObject<Dictionary<string, object>>(json);

// Polymorphism
var data = JsonConvert.SerializeObject(obj, new JsonSerializerSettings
{
    TypeNameHandling = TypeNameHandling.Auto, // includes type info for polymorphic fields
    Formatting = Formatting.Indented
});

// Custom converters for Unity types
public class Vector3Converter : JsonConverter<Vector3>
{
    public override void WriteJson(JsonWriter writer, Vector3 value, JsonSerializer serializer)
    {
        writer.WriteStartObject();
        writer.WritePropertyName("x"); writer.WriteValue(value.x);
        writer.WritePropertyName("y"); writer.WriteValue(value.y);
        writer.WritePropertyName("z"); writer.WriteValue(value.z);
        writer.WriteEndObject();
    }

    public override Vector3 ReadJson(JsonReader reader, Type objectType,
        Vector3 existingValue, bool hasExistingValue, JsonSerializer serializer)
    {
        var obj = Newtonsoft.Json.Linq.JObject.Load(reader);
        return new Vector3(
            obj["x"]?.Value<float>() ?? 0,
            obj["y"]?.Value<float>() ?? 0,
            obj["z"]?.Value<float>() ?? 0);
    }
}
```

## Save File Management

### File Locations

```csharp
// OS-appropriate save location
string savePath = Application.persistentDataPath;
// Windows: C:/Users/<user>/AppData/LocalLow/<company>/<product>/
// macOS:   ~/Library/Application Support/<company>/<product>/
// Linux:   ~/.config/unity3d/<company>/<product>/
// Android: /data/data/<package>/files/
// iOS:     /var/mobile/Containers/Data/Application/<guid>/Documents/

string saveFilePath = Path.Combine(Application.persistentDataPath, "save01.json");
```

### Save Manager Architecture

```csharp
public interface ISaveData
{
    int Version { get; }
}

[System.Serializable]
public class GameSaveData : ISaveData
{
    public int Version => 3; // increment when save format changes

    public int saveVersion; // serialized version for migration
    public string playerName;
    public int level;
    public float playTimeSeconds;
    public SerializableVector3 playerPosition;
    public List<InventorySlot> inventory;
    public Dictionary<string, bool> questFlags; // requires Newtonsoft
    public string saveTimestamp;
}

// Unity Vector3 is not always JSON-friendly — use a wrapper
[System.Serializable]
public struct SerializableVector3
{
    public float x, y, z;

    public SerializableVector3(Vector3 v) { x = v.x; y = v.y; z = v.z; }
    public Vector3 ToVector3() => new(x, y, z);

    public static implicit operator SerializableVector3(Vector3 v) => new(v);
    public static implicit operator Vector3(SerializableVector3 v) => v.ToVector3();
}

[System.Serializable]
public struct InventorySlot
{
    public string itemId;
    public int quantity;
}
```

```csharp
public class SaveManager : MonoBehaviour
{
    public static SaveManager Instance { get; private set; }

    private const string SaveFolder = "saves";
    private const string FileExtension = ".json";

    private void Awake()
    {
        Instance = this;
        EnsureSaveDirectory();
    }

    private string GetSaveDirectory()
    {
        return Path.Combine(Application.persistentDataPath, SaveFolder);
    }

    private void EnsureSaveDirectory()
    {
        string dir = GetSaveDirectory();
        if (!Directory.Exists(dir))
            Directory.CreateDirectory(dir);
    }

    public void Save(GameSaveData data, string slotName = "save01")
    {
        data.saveVersion = data.Version;
        data.saveTimestamp = System.DateTime.UtcNow.ToString("o");

        string json = JsonConvert.SerializeObject(data, Formatting.Indented);
        string path = Path.Combine(GetSaveDirectory(), slotName + FileExtension);

        // Write to temp file first, then rename — prevents corruption on crash
        string tempPath = path + ".tmp";
        File.WriteAllText(tempPath, json);

        if (File.Exists(path))
            File.Delete(path);

        File.Move(tempPath, path);

        Debug.Log($"Game saved to {path}");
    }

    public GameSaveData Load(string slotName = "save01")
    {
        string path = Path.Combine(GetSaveDirectory(), slotName + FileExtension);

        if (!File.Exists(path))
        {
            Debug.LogWarning($"Save file not found: {path}");
            return null;
        }

        string json = File.ReadAllText(path);
        var data = JsonConvert.DeserializeObject<GameSaveData>(json);

        // Version migration
        data = MigrateSave(data);

        Debug.Log($"Game loaded from {path}");
        return data;
    }

    public bool SaveExists(string slotName = "save01")
    {
        string path = Path.Combine(GetSaveDirectory(), slotName + FileExtension);
        return File.Exists(path);
    }

    public void DeleteSave(string slotName = "save01")
    {
        string path = Path.Combine(GetSaveDirectory(), slotName + FileExtension);
        if (File.Exists(path))
            File.Delete(path);
    }

    public string[] GetAllSaveSlots()
    {
        string dir = GetSaveDirectory();
        if (!Directory.Exists(dir)) return System.Array.Empty<string>();

        return Directory.GetFiles(dir, "*" + FileExtension)
            .Select(Path.GetFileNameWithoutExtension)
            .ToArray();
    }

    // Version migration — handle save format changes
    private GameSaveData MigrateSave(GameSaveData data)
    {
        if (data.saveVersion < 2)
        {
            // v1 → v2: added inventory system
            data.inventory ??= new List<InventorySlot>();
            Debug.Log("Migrated save from v1 to v2");
        }

        if (data.saveVersion < 3)
        {
            // v2 → v3: added quest flags
            data.questFlags ??= new Dictionary<string, bool>();
            Debug.Log("Migrated save from v2 to v3");
        }

        data.saveVersion = data.Version;
        return data;
    }
}
```

## Binary Serialization

**WARNING:** `BinaryFormatter` is insecure and deprecated. Do NOT use it. Attackers can craft payloads that execute arbitrary code during deserialization.

### Safe Binary Approach — Custom Writer

```csharp
public static class BinarySaveHelper
{
    public static void WriteSave(string path, GameSaveData data)
    {
        using var stream = File.Open(path, FileMode.Create);
        using var writer = new BinaryWriter(stream);

        writer.Write(data.saveVersion);
        writer.Write(data.playerName ?? "");
        writer.Write(data.level);
        writer.Write(data.playTimeSeconds);
        writer.Write(data.playerPosition.x);
        writer.Write(data.playerPosition.y);
        writer.Write(data.playerPosition.z);

        // Inventory
        writer.Write(data.inventory?.Count ?? 0);
        if (data.inventory != null)
        {
            foreach (var slot in data.inventory)
            {
                writer.Write(slot.itemId ?? "");
                writer.Write(slot.quantity);
            }
        }
    }

    public static GameSaveData ReadSave(string path)
    {
        using var stream = File.Open(path, FileMode.Open);
        using var reader = new BinaryReader(stream);

        var data = new GameSaveData();
        data.saveVersion = reader.ReadInt32();
        data.playerName = reader.ReadString();
        data.level = reader.ReadInt32();
        data.playTimeSeconds = reader.ReadSingle();
        data.playerPosition = new SerializableVector3
        {
            x = reader.ReadSingle(),
            y = reader.ReadSingle(),
            z = reader.ReadSingle()
        };

        int inventoryCount = reader.ReadInt32();
        data.inventory = new List<InventorySlot>(inventoryCount);
        for (int i = 0; i < inventoryCount; i++)
        {
            data.inventory.Add(new InventorySlot
            {
                itemId = reader.ReadString(),
                quantity = reader.ReadInt32()
            });
        }

        return data;
    }
}
```

## Encryption

### Simple XOR (Casual Protection)

Deters save file editing with a text editor but is trivially breakable by anyone who tries:

```csharp
public static class SimpleCrypto
{
    private const string Key = "MyGameSecretKey2024";

    public static string Encrypt(string plainText)
    {
        var result = new char[plainText.Length];
        for (int i = 0; i < plainText.Length; i++)
        {
            result[i] = (char)(plainText[i] ^ Key[i % Key.Length]);
        }
        return System.Convert.ToBase64String(
            System.Text.Encoding.UTF8.GetBytes(new string(result)));
    }

    public static string Decrypt(string cipherText)
    {
        var bytes = System.Convert.FromBase64String(cipherText);
        var text = System.Text.Encoding.UTF8.GetString(bytes);
        var result = new char[text.Length];
        for (int i = 0; i < text.Length; i++)
        {
            result[i] = (char)(text[i] ^ Key[i % Key.Length]);
        }
        return new string(result);
    }
}
```

### AES Encryption (Serious Protection)

```csharp
using System.Security.Cryptography;

public static class AESCrypto
{
    // In production, derive key from hardware ID or similar — don't hardcode
    private static readonly byte[] Key = System.Text.Encoding.UTF8.GetBytes(
        "32CharacterLongKeyForAES256!!!!!");  // exactly 32 bytes for AES-256
    private static readonly byte[] IV = System.Text.Encoding.UTF8.GetBytes(
        "16ByteIVForAES!!");  // exactly 16 bytes

    public static byte[] Encrypt(string plainText)
    {
        using var aes = Aes.Create();
        aes.Key = Key;
        aes.IV = IV;

        var encryptor = aes.CreateEncryptor();
        var plainBytes = System.Text.Encoding.UTF8.GetBytes(plainText);
        return encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
    }

    public static string Decrypt(byte[] cipherBytes)
    {
        using var aes = Aes.Create();
        aes.Key = Key;
        aes.IV = IV;

        var decryptor = aes.CreateDecryptor();
        var plainBytes = decryptor.TransformFinalBlock(cipherBytes, 0, cipherBytes.Length);
        return System.Text.Encoding.UTF8.GetString(plainBytes);
    }
}
```

## ScriptableObject Runtime Data Pattern

Use ScriptableObjects as data templates, but create runtime copies for mutable state:

```csharp
// Asset (read-only template)
[CreateAssetMenu(fileName = "NewCharacter", menuName = "Game/Character Data")]
public class CharacterData : ScriptableObject
{
    public string characterName;
    public int baseHealth;
    public int baseAttack;
    public int baseDefense;
    public Sprite portrait;

    // Create a runtime copy that can be modified
    public CharacterData CreateRuntimeCopy()
    {
        return Instantiate(this);
    }
}

// Usage
public class CharacterManager : MonoBehaviour
{
    [SerializeField] private CharacterData template; // asset reference
    private CharacterData _runtimeData; // mutable copy

    private void Start()
    {
        _runtimeData = template.CreateRuntimeCopy();
        _runtimeData.baseHealth += 10; // safe to modify — won't touch the asset
    }
}
```

## Addressables

The Addressable Asset System replaces `Resources.Load` with async, memory-managed asset loading.

### Setup

1. Install: Package Manager > `com.unity.addressables`
2. Mark assets as Addressable in Inspector
3. Build: Window > Asset Management > Addressables > Groups > Build

### Loading Assets

```csharp
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class AssetLoader : MonoBehaviour
{
    // Inspector reference (type-safe, no string keys)
    [SerializeField] private AssetReference enemyPrefabRef;

    // Or load by address string
    private AsyncOperationHandle<GameObject> _handle;

    public async void LoadEnemy()
    {
        // Async load
        _handle = Addressables.LoadAssetAsync<GameObject>("Prefabs/Enemy");
        await _handle.Task;

        if (_handle.Status == AsyncOperationStatus.Succeeded)
        {
            Instantiate(_handle.Result, transform.position, Quaternion.identity);
        }
    }

    // Using AssetReference
    public async void LoadFromReference()
    {
        var handle = enemyPrefabRef.LoadAssetAsync<GameObject>();
        await handle.Task;

        if (handle.Status == AsyncOperationStatus.Succeeded)
        {
            Instantiate(handle.Result);
        }
    }

    // IMPORTANT: Release when done to free memory
    private void OnDestroy()
    {
        if (_handle.IsValid())
            Addressables.Release(_handle);
    }
}
```

### Label-Based Loading

```csharp
// Load all assets with a label
public async void LoadAllWeapons()
{
    var handle = Addressables.LoadAssetsAsync<WeaponData>(
        "weapons",    // label
        weapon => { Debug.Log($"Loaded: {weapon.name}"); } // callback per item
    );

    var weapons = await handle.Task;
    Debug.Log($"Loaded {weapons.Count} weapons");
}
```

### Async Scene Loading

```csharp
public async void LoadLevel(string sceneAddress)
{
    var handle = Addressables.LoadSceneAsync(sceneAddress,
        UnityEngine.SceneManagement.LoadSceneMode.Single);
    await handle.Task;

    if (handle.Status == AsyncOperationStatus.Succeeded)
        Debug.Log("Scene loaded");
}
```

## Resources Folder

`Resources.Load` is synchronous and convenient but has downsides:

```csharp
// Load from Assets/Resources/
var prefab = Resources.Load<GameObject>("Prefabs/Enemy");
var texture = Resources.Load<Texture2D>("Textures/icon");
var all = Resources.LoadAll<AudioClip>("Audio/SFX");
```

**Why to avoid Resources:**
- ALL assets in Resources/ are included in the build, even if unused
- Cannot be unloaded individually
- Causes longer build times
- No async loading
- Prefer Addressables for anything beyond prototyping

## StreamingAssets

Files in `Assets/StreamingAssets/` are included in the build as-is (not processed by Unity). Useful for raw config files, databases, or pre-built data.

```csharp
// Read a file from StreamingAssets
string path = Path.Combine(Application.streamingAssetsPath, "config.json");

// Platform differences:
// Windows/Mac/Linux: file:// path, can use File.ReadAllText
// Android: jar:// path, must use UnityWebRequest
// WebGL: http:// path, must use UnityWebRequest

#if UNITY_ANDROID && !UNITY_EDITOR
    // Android requires UnityWebRequest
    using var www = UnityWebRequest.Get(path);
    yield return www.SendWebRequest();
    string json = www.downloadHandler.text;
#else
    string json = File.ReadAllText(path);
#endif
```

## Cloud Saves

### Steam Cloud (via Steamworks.NET)

```csharp
public class SteamCloudSave
{
    public static void SaveToCloud(string fileName, byte[] data)
    {
        if (!SteamRemoteStorage.FileWrite(fileName, data, data.Length))
        {
            Debug.LogError("Failed to write to Steam Cloud");
        }
    }

    public static byte[] LoadFromCloud(string fileName)
    {
        if (!SteamRemoteStorage.FileExists(fileName))
            return null;

        int fileSize = SteamRemoteStorage.GetFileSize(fileName);
        byte[] data = new byte[fileSize];
        SteamRemoteStorage.FileRead(fileName, data, fileSize);
        return data;
    }
}
```

### Conflict Resolution Pattern

When local and cloud saves diverge (e.g., played offline):

```csharp
public class SaveConflictResolver
{
    public enum Resolution { UseLocal, UseCloud, UseMostRecent }

    public static GameSaveData Resolve(
        GameSaveData localSave,
        GameSaveData cloudSave,
        Resolution strategy = Resolution.UseMostRecent)
    {
        if (localSave == null) return cloudSave;
        if (cloudSave == null) return localSave;

        return strategy switch
        {
            Resolution.UseLocal => localSave,
            Resolution.UseCloud => cloudSave,
            Resolution.UseMostRecent =>
                System.DateTime.Parse(localSave.saveTimestamp) >
                System.DateTime.Parse(cloudSave.saveTimestamp)
                    ? localSave : cloudSave,
            _ => cloudSave
        };
    }
}
```

## Auto-Save Pattern

```csharp
public class AutoSaveManager : MonoBehaviour
{
    [SerializeField] private float autoSaveIntervalSeconds = 300f; // 5 minutes
    private float _timeSinceLastSave;

    private void Update()
    {
        _timeSinceLastSave += Time.unscaledDeltaTime;

        if (_timeSinceLastSave >= autoSaveIntervalSeconds)
        {
            _timeSinceLastSave = 0f;
            PerformAutoSave();
        }
    }

    private void PerformAutoSave()
    {
        var data = GatherSaveData();
        SaveManager.Instance.Save(data, "autosave");
        Debug.Log("Auto-save completed");
    }

    // Also save on application pause/quit
    private void OnApplicationPause(bool pauseStatus)
    {
        if (pauseStatus) PerformAutoSave();
    }

    private void OnApplicationQuit()
    {
        PerformAutoSave();
    }

    private GameSaveData GatherSaveData() { /* collect current game state */ return new GameSaveData(); }
}
```

## Summary — When to Use What

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **PlayerPrefs** | Settings (volume, quality) | Simple, cross-platform | Not secure, no structured data |
| **JsonUtility** | Simple save data, no Dictionary | Fast, zero dependencies | Limited type support |
| **Newtonsoft.Json** | Complex save data, Dictionary, polymorphism | Full-featured | External dependency |
| **Custom binary** | Performance-critical or large saves | Small files, fast | Manual maintenance |
| **Addressables** | Asset loading (prefabs, textures, audio) | Async, memory-managed, CDN support | Setup complexity |
| **Resources** | Quick prototyping only | Simple API | Build bloat, no async |
| **StreamingAssets** | Raw files (configs, databases) | Unprocessed, platform-native | Platform-specific loading |
| **ScriptableObject** | Game data templates (items, enemies) | Editor-friendly, reusable | Not for mutable runtime state |
