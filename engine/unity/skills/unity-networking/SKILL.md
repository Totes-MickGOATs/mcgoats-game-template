# Unity Networking

Reference guide for multiplayer networking in Unity using Netcode for GameObjects (NGO).
Covers setup, NetworkBehaviour, RPCs, state sync, spawning, and common patterns.

## Package Setup

```json
// Packages/manifest.json
"com.unity.netcode.gameobjects": "2.1.1",
"com.unity.transport": "2.3.0"
```

For Unity Gaming Services (relay, lobby):
```json
"com.unity.services.relay": "1.1.1",
"com.unity.services.lobby": "1.2.2",
"com.unity.services.authentication": "3.3.3"
```

## NetworkManager

The central singleton that manages the network session.

### Setup

1. Create a GameObject with **NetworkManager** component
2. Assign a **Unity Transport** component (same or child GameObject)
3. Configure the **Player Prefab** (must have NetworkObject component)
4. Register all spawnable prefabs in **Network Prefabs List**

```csharp
// Starting a session
NetworkManager.Singleton.StartHost();    // Server + Client (host model)
NetworkManager.Singleton.StartServer();  // Dedicated server
NetworkManager.Singleton.StartClient();  // Client connecting to server

// Connection settings (on UnityTransport component)
var transport = NetworkManager.Singleton.GetComponent<UnityTransport>();
transport.ConnectionData.Address = "127.0.0.1";
transport.ConnectionData.Port = 7777;

// Shutdown
NetworkManager.Singleton.Shutdown();
```

### Connection Callbacks

```csharp
public class ConnectionManager : MonoBehaviour
{
    void Start()
    {
        NetworkManager.Singleton.OnClientConnectedCallback += OnClientConnected;
        NetworkManager.Singleton.OnClientDisconnectCallback += OnClientDisconnected;
        NetworkManager.Singleton.ConnectionApprovalCallback += ApprovalCheck;
    }

    void OnClientConnected(ulong clientId)
    {
        Debug.Log($"Client {clientId} connected");
    }

    void OnClientDisconnected(ulong clientId)
    {
        Debug.Log($"Client {clientId} disconnected");
    }

    // Custom approval (password, version check, player limit)
    void ApprovalCheck(NetworkManager.ConnectionApprovalRequest request,
                       NetworkManager.ConnectionApprovalResponse response)
    {
        string password = System.Text.Encoding.UTF8.GetString(request.Payload);
        response.Approved = password == "secret123";
        response.CreatePlayerObject = true;
        response.Position = GetSpawnPosition();
        response.Rotation = Quaternion.identity;
    }
}
```

## NetworkBehaviour

Base class for scripts that participate in networking. Must be on a GameObject with NetworkObject.

### Key Properties

| Property | Purpose |
|----------|---------|
| `IsOwner` | True if this client owns this object |
| `IsServer` | True if running on server/host |
| `IsClient` | True if running as client (host is both) |
| `IsHost` | True if both server and client |
| `IsLocalPlayer` | True if this is the local player's object |
| `IsSpawned` | True after network spawn |
| `OwnerClientId` | The clientId that owns this object |
| `NetworkObjectId` | Unique ID across the network |

### Lifecycle

```csharp
public class PlayerController : NetworkBehaviour
{
    public override void OnNetworkSpawn()
    {
        // Called when object is spawned on the network
        // Safe to access IsOwner, IsServer, etc.
        if (IsOwner)
        {
            // Setup local player (camera, input)
            EnableInput();
        }
        else
        {
            // Remote player -- disable input
            DisableInput();
        }
    }

    public override void OnNetworkDespawn()
    {
        // Cleanup
    }
}
```

## NetworkObject

Every networked GameObject needs a **NetworkObject** component.

### Spawning

```csharp
// Server-side spawning
public class EnemySpawner : NetworkBehaviour
{
    [SerializeField] GameObject _enemyPrefab; // Must be in NetworkManager's prefab list

    public void SpawnEnemy(Vector3 position)
    {
        if (!IsServer) return;

        GameObject enemy = Instantiate(_enemyPrefab, position, Quaternion.identity);
        enemy.GetComponent<NetworkObject>().Spawn(); // Server-owned

        // Or spawn with client ownership:
        // enemy.GetComponent<NetworkObject>().SpawnWithOwnership(clientId);
    }

    public void DespawnEnemy(NetworkObject enemy)
    {
        if (!IsServer) return;
        enemy.Despawn(); // Removes from all clients
        // enemy.Despawn(destroy: false); // Despawn but keep the GameObject
    }
}
```

### Player Prefab

The player prefab assigned in NetworkManager is automatically spawned for each connected client. The connecting client is the owner.

```csharp
// Accessing the local player
NetworkObject localPlayer = NetworkManager.Singleton.SpawnManager
    .GetLocalPlayerObject();
```

## NetworkVariable

Synchronized state that the server authorizes and replicates to clients.

```csharp
public class PlayerStats : NetworkBehaviour
{
    // Server-writable, everyone can read (default)
    public NetworkVariable<int> Health = new(
        100,
        NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Server
    );

    // Owner-writable (for client-authoritative state)
    public NetworkVariable<Vector3> AimDirection = new(
        Vector3.forward,
        NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Owner
    );

    public override void OnNetworkSpawn()
    {
        Health.OnValueChanged += OnHealthChanged;
    }

    public override void OnNetworkDespawn()
    {
        Health.OnValueChanged -= OnHealthChanged;
    }

    void OnHealthChanged(int oldValue, int newValue)
    {
        // Update health bar UI
        _healthBar.SetHealth(newValue);

        if (newValue <= 0)
            OnDeath();
    }

    // Server-side: modify health
    [ServerRpc]
    public void TakeDamageServerRpc(int damage)
    {
        Health.Value = Mathf.Max(0, Health.Value - damage);
    }
}
```

### Supported Types

Built-in: `bool`, `byte`, `sbyte`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`, `float`, `double`, `Vector2`, `Vector3`, `Vector4`, `Quaternion`, `Color`, `Color32`, `Ray`, `Ray2D`

For custom types, implement `INetworkSerializable`:

```csharp
public struct PlayerData : INetworkSerializable
{
    public FixedString64Bytes PlayerName;
    public int TeamId;
    public int Score;

    public void NetworkSerialize<T>(BufferSerializer<T> serializer)
        where T : IReaderWriter
    {
        serializer.SerializeValue(ref PlayerName);
        serializer.SerializeValue(ref TeamId);
        serializer.SerializeValue(ref Score);
    }
}

// Usage:
public NetworkVariable<PlayerData> Data = new();
```

### NetworkList

For synchronized collections:

```csharp
public NetworkList<int> Scores;

void Awake()
{
    Scores = new NetworkList<int>();
}

public override void OnNetworkSpawn()
{
    Scores.OnListChanged += OnScoresChanged;
}

void OnScoresChanged(NetworkListEvent<int> changeEvent)
{
    // changeEvent.Type: Add, Remove, Value, Insert, RemoveAt, Clear
    // changeEvent.Index, changeEvent.Value, changeEvent.PreviousValue
    RefreshScoreboard();
}
```

## RPCs (Remote Procedure Calls)

### ServerRpc

Client calls, server executes. Method name must end with `ServerRpc`.

```csharp
// Default: only the owner can call
[ServerRpc]
void RequestFireServerRpc(Vector3 direction)
{
    // Runs on server
    SpawnProjectile(direction);
    NotifyFireClientRpc(direction); // Notify all clients
}

// Allow any client to call (not just owner)
[ServerRpc(RequireOwnership = false)]
void RequestInteractServerRpc(ulong objectId, ServerRpcParams rpcParams = default)
{
    ulong senderId = rpcParams.Receive.SenderClientId;
    Debug.Log($"Client {senderId} wants to interact with {objectId}");
}
```

### ClientRpc

Server calls, clients execute. Method name must end with `ClientRpc`.

```csharp
// Broadcast to all clients
[ClientRpc]
void NotifyFireClientRpc(Vector3 direction)
{
    // Runs on all clients (including host)
    PlayMuzzleFlash(direction);
    PlayFireSound();
}

// Send to specific clients
[ClientRpc]
void SendPrivateMessageClientRpc(string message, ClientRpcParams rpcParams = default)
{
    ShowMessage(message);
}

// Usage: send to specific client
void SendToClient(ulong clientId, string msg)
{
    var rpcParams = new ClientRpcParams
    {
        Send = new ClientRpcSendParams
        {
            TargetClientIds = new[] { clientId }
        }
    };
    SendPrivateMessageClientRpc(msg, rpcParams);
}
```

### When to Use Each

| Scenario | Pattern |
|----------|---------|
| Player shoots | Client -> `ShootServerRpc` -> Server validates -> `ShootEffectsClientRpc` |
| Pickup item | Client -> `PickupServerRpc` -> Server checks availability -> modifies NetworkVariable |
| Chat message | Client -> `SendChatServerRpc` -> Server -> `ReceiveChatClientRpc` (broadcast) |
| Damage dealt | Server calculates -> modifies Health NetworkVariable -> `OnValueChanged` on clients |
| Game state change | Server modifies NetworkVariable -> all clients notified |

## Client-Server Authority Model

### Server-Authoritative (Recommended)

The server is the source of truth. Clients send requests, server validates and applies.

```csharp
public class ServerAuthoritativeMovement : NetworkBehaviour
{
    [SerializeField] float _speed = 5f;

    // Server owns the position (via NetworkTransform with Server authority)

    void Update()
    {
        if (!IsOwner) return;

        // Client: read input, send to server
        Vector3 input = new Vector3(Input.GetAxis("Horizontal"), 0, Input.GetAxis("Vertical"));
        if (input.sqrMagnitude > 0.01f)
            MoveServerRpc(input.normalized);
    }

    [ServerRpc]
    void MoveServerRpc(Vector3 direction)
    {
        // Server: validate and apply movement
        transform.position += direction * _speed * Time.deltaTime;
    }
}
```

### Client Prediction (Advanced)

For responsive gameplay, predict movement locally and reconcile with server:

```csharp
public class PredictedMovement : NetworkBehaviour
{
    NetworkVariable<Vector3> _serverPosition = new();
    Vector3 _predictedPosition;
    Queue<MoveInput> _pendingInputs = new();

    void Update()
    {
        if (!IsOwner) return;

        // 1. Read input
        var input = new MoveInput { Direction = GetInputDirection(), Tick = _currentTick };

        // 2. Predict locally
        _predictedPosition = ApplyMovement(_predictedPosition, input);
        transform.position = _predictedPosition;

        // 3. Send to server
        _pendingInputs.Enqueue(input);
        SendInputServerRpc(input);
    }

    void OnServerPositionChanged(Vector3 oldPos, Vector3 newPos)
    {
        // 4. Reconcile: discard acknowledged inputs, replay pending
        while (_pendingInputs.Count > 0 && _pendingInputs.Peek().Tick <= _lastAckedTick)
            _pendingInputs.Dequeue();

        _predictedPosition = newPos;
        foreach (var input in _pendingInputs)
            _predictedPosition = ApplyMovement(_predictedPosition, input);

        transform.position = _predictedPosition;
    }
}
```

## State Synchronization

### NetworkTransform

Synchronizes transform automatically:

```csharp
// Add NetworkTransform component to the GameObject
// Configure:
//   Sync Position X/Y/Z: enable axes you need
//   Threshold: minimum change to trigger sync (reduces bandwidth)
//   Authority: Server (default) or Owner

// For client-authoritative movement (e.g., player character):
// Use ClientNetworkTransform (from NGO Samples) instead
```

### NetworkAnimator

Synchronizes Animator parameters and state:

```
// Add NetworkAnimator component
// Assign the Animator
// Triggers, bools, floats, ints are synced automatically
```

### Custom Synchronization

For data that does not fit NetworkVariable or standard components:

```csharp
public class CustomSync : NetworkBehaviour
{
    // Efficient: only sync what changes
    public NetworkVariable<byte> WeaponIndex = new();
    public NetworkVariable<bool> IsCrouching = new();
    public NetworkVariable<float> AimAngle = new();

    // For complex/infrequent state, use RPCs instead of NetworkVariables
    [ClientRpc]
    void SyncInventoryClientRpc(int[] itemIds, int[] quantities)
    {
        // Rebuild inventory on clients
    }
}
```

## Relay and Lobby (Unity Gaming Services)

### Relay Setup (No Port Forwarding Needed)

```csharp
using Unity.Services.Core;
using Unity.Services.Authentication;
using Unity.Services.Relay;
using Unity.Services.Relay.Models;
using Unity.Networking.Transport.Relay;

public class RelayManager : MonoBehaviour
{
    async void Start()
    {
        await UnityServices.InitializeAsync();
        await AuthenticationService.Instance.SignInAnonymouslyAsync();
    }

    public async Task<string> CreateRelay(int maxPlayers)
    {
        Allocation allocation = await RelayService.Instance
            .CreateAllocationAsync(maxPlayers - 1); // Minus host

        string joinCode = await RelayService.Instance
            .GetJoinCodeAsync(allocation.AllocationId);

        var relayServerData = new RelayServerData(allocation, "dtls");
        NetworkManager.Singleton.GetComponent<UnityTransport>()
            .SetRelayServerData(relayServerData);

        NetworkManager.Singleton.StartHost();
        return joinCode; // Share this with other players
    }

    public async Task JoinRelay(string joinCode)
    {
        JoinAllocation allocation = await RelayService.Instance
            .JoinAllocationAsync(joinCode);

        var relayServerData = new RelayServerData(allocation, "dtls");
        NetworkManager.Singleton.GetComponent<UnityTransport>()
            .SetRelayServerData(relayServerData);

        NetworkManager.Singleton.StartClient();
    }
}
```

### Lobby Setup

```csharp
using Unity.Services.Lobbies;
using Unity.Services.Lobbies.Models;

public class LobbyManager : MonoBehaviour
{
    Lobby _currentLobby;
    float _heartbeatTimer;

    public async Task<Lobby> CreateLobby(string name, int maxPlayers, string relayCode)
    {
        var options = new CreateLobbyOptions
        {
            IsPrivate = false,
            Data = new Dictionary<string, DataObject>
            {
                { "RelayCode", new DataObject(DataObject.VisibilityOptions.Public, relayCode) },
                { "GameMode", new DataObject(DataObject.VisibilityOptions.Public, "Deathmatch") }
            }
        };

        _currentLobby = await LobbyService.Instance.CreateLobbyAsync(name, maxPlayers, options);
        return _currentLobby;
    }

    public async Task<List<Lobby>> ListLobbies()
    {
        var options = new QueryLobbiesOptions
        {
            Filters = new List<QueryFilter>
            {
                new(QueryFilter.FieldOptions.AvailableSlots, "0", QueryFilter.OpOptions.GT)
            },
            Order = new List<QueryOrder>
            {
                new(false, QueryOrder.FieldOptions.Created) // Newest first
            }
        };

        QueryResponse response = await Lobbies.Instance.QueryLobbiesAsync(options);
        return response.Results;
    }

    public async Task JoinLobby(string lobbyId)
    {
        _currentLobby = await LobbyService.Instance.JoinLobbyByIdAsync(lobbyId);
        string relayCode = _currentLobby.Data["RelayCode"].Value;
        await _relayManager.JoinRelay(relayCode);
    }

    // Host must send heartbeat every 15 seconds to keep lobby alive
    void Update()
    {
        if (_currentLobby == null || !IsHost()) return;
        _heartbeatTimer -= Time.deltaTime;
        if (_heartbeatTimer <= 0f)
        {
            _heartbeatTimer = 15f;
            LobbyService.Instance.SendHeartbeatPingAsync(_currentLobby.Id);
        }
    }
}
```

## Scene Management

### NetworkSceneManager

Server controls scene loading for all clients:

```csharp
// Server-side scene loading
public class GameFlowManager : NetworkBehaviour
{
    public void LoadGameScene()
    {
        if (!IsServer) return;
        NetworkManager.Singleton.SceneManager.LoadScene("GameScene", LoadSceneMode.Single);
    }

    void OnEnable()
    {
        NetworkManager.Singleton.SceneManager.OnLoadComplete += OnSceneLoadComplete;
    }

    void OnSceneLoadComplete(ulong clientId, string sceneName, LoadSceneMode mode)
    {
        Debug.Log($"Client {clientId} finished loading {sceneName}");
    }
}
```

## LAN Discovery

For local network games without Unity Gaming Services:

```csharp
public class LANDiscovery : MonoBehaviour
{
    [SerializeField] int _broadcastPort = 47777;
    [SerializeField] float _broadcastInterval = 1f;

    UdpClient _broadcastClient;
    UdpClient _listenClient;
    readonly List<ServerInfo> _discoveredServers = new();

    public struct ServerInfo
    {
        public string Name;
        public string Address;
        public int Port;
        public int PlayerCount;
        public int MaxPlayers;
    }

    // Host: broadcast presence
    public void StartBroadcasting(string serverName, int gamePort)
    {
        _broadcastClient = new UdpClient();
        _broadcastClient.EnableBroadcast = true;
        StartCoroutine(BroadcastLoop(serverName, gamePort));
    }

    IEnumerator BroadcastLoop(string name, int port)
    {
        var endpoint = new IPEndPoint(IPAddress.Broadcast, _broadcastPort);
        while (true)
        {
            string msg = $"GAME|{name}|{port}|{GetPlayerCount()}|{GetMaxPlayers()}";
            byte[] data = Encoding.UTF8.GetBytes(msg);
            _broadcastClient.Send(data, data.Length, endpoint);
            yield return new WaitForSeconds(_broadcastInterval);
        }
    }

    // Client: listen for broadcasts
    public void StartListening()
    {
        _listenClient = new UdpClient(_broadcastPort);
        _listenClient.EnableBroadcast = true;
        _listenClient.BeginReceive(OnReceive, null);
    }

    void OnReceive(IAsyncResult result)
    {
        var endpoint = new IPEndPoint(IPAddress.Any, 0);
        byte[] data = _listenClient.EndReceive(result, ref endpoint);
        string msg = Encoding.UTF8.GetString(data);
        string[] parts = msg.Split('|');

        if (parts[0] == "GAME")
        {
            var server = new ServerInfo
            {
                Name = parts[1],
                Address = endpoint.Address.ToString(),
                Port = int.Parse(parts[2]),
                PlayerCount = int.Parse(parts[3]),
                MaxPlayers = int.Parse(parts[4])
            };
            // Add to discovered list (main thread via queue)
        }

        _listenClient.BeginReceive(OnReceive, null);
    }
}
```

## Common Patterns

### Lobby Ready-Check and Countdown

```csharp
public class LobbyController : NetworkBehaviour
{
    public NetworkList<bool> PlayerReady;
    public NetworkVariable<float> CountdownTimer = new(-1f);
    const float COUNTDOWN_DURATION = 5f;

    void Awake() => PlayerReady = new NetworkList<bool>();

    [ServerRpc(RequireOwnership = false)]
    public void SetReadyServerRpc(bool ready, ServerRpcParams rpcParams = default)
    {
        int index = GetPlayerIndex(rpcParams.Receive.SenderClientId);
        PlayerReady[index] = ready;

        if (AllPlayersReady())
            CountdownTimer.Value = COUNTDOWN_DURATION;
        else
            CountdownTimer.Value = -1f; // Cancel countdown
    }

    void Update()
    {
        if (!IsServer || CountdownTimer.Value < 0) return;

        CountdownTimer.Value -= Time.deltaTime;
        if (CountdownTimer.Value <= 0f)
        {
            CountdownTimer.Value = -1f;
            StartGame();
        }
    }

    bool AllPlayersReady()
    {
        if (PlayerReady.Count == 0) return false;
        foreach (bool ready in PlayerReady)
            if (!ready) return false;
        return true;
    }
}
```

### Object Spawn Pooling

```csharp
public class NetworkObjectPool : MonoBehaviour
{
    [SerializeField] GameObject _prefab;
    [SerializeField] int _preSpawnCount = 20;
    Queue<NetworkObject> _pool = new();

    void Start()
    {
        NetworkManager.Singleton.PrefabHandler.AddHandler(
            _prefab, new PooledPrefabHandler(this));

        for (int i = 0; i < _preSpawnCount; i++)
        {
            var obj = Instantiate(_prefab).GetComponent<NetworkObject>();
            obj.gameObject.SetActive(false);
            _pool.Enqueue(obj);
        }
    }

    public NetworkObject Get()
    {
        if (_pool.Count == 0)
        {
            var obj = Instantiate(_prefab).GetComponent<NetworkObject>();
            return obj;
        }
        var pooled = _pool.Dequeue();
        pooled.gameObject.SetActive(true);
        return pooled;
    }

    public void Return(NetworkObject obj)
    {
        obj.gameObject.SetActive(false);
        _pool.Enqueue(obj);
    }
}
```

### Host Migration Considerations

NGO does not have built-in host migration. Options:

1. **Dedicated server**: Avoids the problem entirely
2. **Relay with reconnection**: When host drops, a new host creates a relay and all clients rejoin
3. **State checkpointing**: Periodically save game state so a new host can restore it
4. **Use a different transport**: Some community transports support migration

For most games, **dedicated server** or **graceful session end on host disconnect** is the pragmatic choice.
