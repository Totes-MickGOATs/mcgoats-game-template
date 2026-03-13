# Unity State Machines

> State machine patterns for game logic, AI, animations, and UI flow -- from Unity's Animator to custom FSM implementations.

## When to Use a State Machine

Use a state machine when an entity has:
- Distinct behavioral modes (idle, running, attacking, dead)
- Rules about which transitions are valid (can't attack while dead)
- Entry/exit logic per state (play animation on enter, stop particles on exit)

If you have nested `if/else` chains checking booleans (`_isAttacking && !_isDead && _isGrounded`), you need a state machine.

## Unity Animator as a State Machine

The Animator Controller is a visual state machine. Useful for character animation but also works as a general-purpose FSM.

### Setup

1. Create Animator Controller (right-click -> Create -> Animator Controller)
2. Add states (right-click -> Create State -> Empty or From Blend Tree)
3. Add transitions between states (right-click state -> Make Transition)
4. Add parameters (Bool, Int, Float, Trigger) to drive transitions
5. Attach Animator component to GameObject, assign the controller

### Driving the Animator from Code

```csharp
public class CharacterAnimator : MonoBehaviour
{
    // Cache parameter hashes (avoid string lookups every frame)
    private static readonly int SpeedHash = Animator.StringToHash("Speed");
    private static readonly int IsGroundedHash = Animator.StringToHash("IsGrounded");
    private static readonly int AttackHash = Animator.StringToHash("Attack");
    private static readonly int DieHash = Animator.StringToHash("Die");

    private Animator _animator;

    private void Awake() => _animator = GetComponent<Animator>();

    public void SetSpeed(float speed) => _animator.SetFloat(SpeedHash, speed);
    public void SetGrounded(bool grounded) => _animator.SetBool(IsGroundedHash, grounded);
    public void TriggerAttack() => _animator.SetTrigger(AttackHash);
    public void TriggerDeath() => _animator.SetTrigger(DieHash);
}
```

**Rule:** Always use `Animator.StringToHash()` cached in `static readonly` fields. Never pass raw strings to `SetFloat`/`SetBool`/`SetTrigger` -- string hashing every frame is wasteful.

### StateMachineBehaviour

Attach scripts directly to Animator states. They receive lifecycle callbacks.

```csharp
public class AttackState : StateMachineBehaviour
{
    [SerializeField] private float _damageDelay = 0.3f;
    private bool _hasDealtDamage;

    // Called when the state is entered
    public override void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        _hasDealtDamage = false;
        // Play attack sound, show VFX, etc.
    }

    // Called every frame while in this state
    public override void OnStateUpdate(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        // Deal damage at the right moment in the animation
        if (!_hasDealtDamage && stateInfo.normalizedTime >= _damageDelay)
        {
            _hasDealtDamage = true;
            var combat = animator.GetComponent<CombatController>();
            combat.DealDamage();
        }
    }

    // Called when transitioning out of this state
    public override void OnStateExit(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        // Clean up: hide VFX, reset flags
    }
}
```

**Gotcha:** `StateMachineBehaviour` instances are shared across Animator instances by default. Use `OnStateEnter` to reset per-instance state. For truly instance-specific data, get it from the Animator's GameObject.

### When Animator FSM is Appropriate

- Character animation states that map 1:1 to game states
- Simple AI with a few states (idle, patrol, chase)
- Quick prototyping -- visual state graph is easy to iterate

### When Animator FSM is Wrong

- Complex game logic with many conditions (Animator transitions get unmanageable)
- States that don't correspond to animations
- Need to unit test state logic
- More than ~10 states (the visual graph becomes spaghetti)

## Custom FSM Implementation

### Core Interface

```csharp
public interface IState
{
    void Enter();
    void Update();
    void FixedUpdate();
    void Exit();
}
```

### State Machine Class

```csharp
public class StateMachine
{
    private IState _currentState;
    private Dictionary<System.Type, IState> _states = new();

    public IState CurrentState => _currentState;

    public void AddState(IState state)
    {
        _states[state.GetType()] = state;
    }

    public void SetState<T>() where T : IState
    {
        if (!_states.TryGetValue(typeof(T), out var newState))
        {
            Debug.LogError($"State {typeof(T).Name} not registered.");
            return;
        }

        if (_currentState == newState) return;

        _currentState?.Exit();
        _currentState = newState;
        _currentState.Enter();
    }

    public void Update() => _currentState?.Update();
    public void FixedUpdate() => _currentState?.FixedUpdate();
}
```

### Concrete States

```csharp
public class PlayerIdleState : IState
{
    private readonly PlayerController _player;
    private readonly StateMachine _fsm;

    public PlayerIdleState(PlayerController player, StateMachine fsm)
    {
        _player = player;
        _fsm = fsm;
    }

    public void Enter()
    {
        _player.Animator.SetSpeed(0f);
    }

    public void Update()
    {
        if (_player.Input.MoveInput.sqrMagnitude > 0.01f)
        {
            _fsm.SetState<PlayerRunState>();
            return;
        }

        if (_player.Input.JumpPressed)
        {
            _fsm.SetState<PlayerJumpState>();
            return;
        }
    }

    public void FixedUpdate() { }

    public void Exit() { }
}

public class PlayerRunState : IState
{
    private readonly PlayerController _player;
    private readonly StateMachine _fsm;

    public PlayerRunState(PlayerController player, StateMachine fsm)
    {
        _player = player;
        _fsm = fsm;
    }

    public void Enter()
    {
        // Start run particles, footstep audio, etc.
    }

    public void Update()
    {
        float speed = _player.Input.MoveInput.magnitude;
        _player.Animator.SetSpeed(speed);

        if (speed < 0.01f)
        {
            _fsm.SetState<PlayerIdleState>();
            return;
        }

        if (_player.Input.JumpPressed)
        {
            _fsm.SetState<PlayerJumpState>();
        }
    }

    public void FixedUpdate()
    {
        _player.Move(_player.Input.MoveInput);
    }

    public void Exit()
    {
        // Stop run particles
    }
}
```

### Wiring It Up

```csharp
public class PlayerController : MonoBehaviour
{
    private StateMachine _fsm;

    public PlayerInput Input { get; private set; }
    public CharacterAnimator Animator { get; private set; }
    public Rigidbody Rigidbody { get; private set; }

    private void Awake()
    {
        Input = GetComponent<PlayerInput>();
        Animator = GetComponent<CharacterAnimator>();
        Rigidbody = GetComponent<Rigidbody>();

        _fsm = new StateMachine();
        _fsm.AddState(new PlayerIdleState(this, _fsm));
        _fsm.AddState(new PlayerRunState(this, _fsm));
        _fsm.AddState(new PlayerJumpState(this, _fsm));
        _fsm.AddState(new PlayerFallState(this, _fsm));

        _fsm.SetState<PlayerIdleState>();
    }

    private void Update() => _fsm.Update();
    private void FixedUpdate() => _fsm.FixedUpdate();

    public void Move(Vector2 input)
    {
        Vector3 move = new Vector3(input.x, 0f, input.y) * _moveSpeed;
        Rigidbody.linearVelocity = new Vector3(move.x, Rigidbody.linearVelocity.y, move.z);
    }
}
```

## Hierarchical State Machine

States that contain sub-state machines. Example: `Combat` state has sub-states `Aiming`, `Firing`, `Reloading`.

```csharp
public interface IState
{
    void Enter();
    void Update();
    void FixedUpdate();
    void Exit();
}

public class HierarchicalState : IState
{
    private readonly StateMachine _subStateMachine = new();

    public StateMachine SubStates => _subStateMachine;

    public virtual void Enter()
    {
        // Set initial sub-state in derived class
    }

    public virtual void Update()
    {
        _subStateMachine.Update();
    }

    public virtual void FixedUpdate()
    {
        _subStateMachine.FixedUpdate();
    }

    public virtual void Exit()
    {
        // Exit current sub-state
        _subStateMachine.CurrentState?.Exit();
    }
}

// Top-level state with sub-states
public class CombatState : HierarchicalState
{
    private readonly PlayerController _player;
    private readonly StateMachine _parentFsm;

    public CombatState(PlayerController player, StateMachine parentFsm)
    {
        _player = player;
        _parentFsm = parentFsm;

        SubStates.AddState(new AimingSubState(_player, SubStates));
        SubStates.AddState(new FiringSubState(_player, SubStates));
        SubStates.AddState(new ReloadingSubState(_player, SubStates));
    }

    public override void Enter()
    {
        base.Enter();
        SubStates.SetState<AimingSubState>();
        _player.Animator.SetCombatMode(true);
    }

    public override void Update()
    {
        // Check for exit conditions at the parent level
        if (_player.Input.CancelPressed)
        {
            _parentFsm.SetState<PlayerIdleState>();
            return;
        }

        // Otherwise, delegate to sub-state
        base.Update();
    }

    public override void Exit()
    {
        base.Exit();
        _player.Animator.SetCombatMode(false);
    }
}
```

## ScriptableObject State Pattern

States as SO assets -- enables designer-driven AI without code changes.

```csharp
// Base state as ScriptableObject
public abstract class AIState : ScriptableObject
{
    public abstract void Enter(AIController ai);
    public abstract void Update(AIController ai);
    public abstract void Exit(AIController ai);
}

// Concrete state assets
[CreateAssetMenu(menuName = "AI/States/Patrol State")]
public class PatrolState : AIState
{
    [SerializeField] private float _patrolSpeed = 3f;
    [SerializeField] private float _detectionRange = 15f;
    [SerializeField] private AIState _chaseState;     // Drag the Chase SO asset here

    public override void Enter(AIController ai)
    {
        ai.Agent.speed = _patrolSpeed;
        ai.SetNextPatrolPoint();
    }

    public override void Update(AIController ai)
    {
        // Check for player in range
        if (ai.DistanceToPlayer < _detectionRange)
        {
            ai.TransitionTo(_chaseState);
            return;
        }

        // Move to patrol point
        if (ai.Agent.remainingDistance < 0.5f)
        {
            ai.SetNextPatrolPoint();
        }
    }

    public override void Exit(AIController ai) { }
}

[CreateAssetMenu(menuName = "AI/States/Chase State")]
public class ChaseState : AIState
{
    [SerializeField] private float _chaseSpeed = 6f;
    [SerializeField] private float _attackRange = 2f;
    [SerializeField] private float _giveUpRange = 25f;
    [SerializeField] private AIState _patrolState;
    [SerializeField] private AIState _attackState;

    public override void Enter(AIController ai)
    {
        ai.Agent.speed = _chaseSpeed;
    }

    public override void Update(AIController ai)
    {
        ai.Agent.SetDestination(ai.PlayerPosition);

        if (ai.DistanceToPlayer < _attackRange)
        {
            ai.TransitionTo(_attackState);
        }
        else if (ai.DistanceToPlayer > _giveUpRange)
        {
            ai.TransitionTo(_patrolState);
        }
    }

    public override void Exit(AIController ai) { }
}

// AI Controller that uses SO states
public class AIController : MonoBehaviour
{
    [SerializeField] private AIState _initialState;

    public NavMeshAgent Agent { get; private set; }
    public float DistanceToPlayer => Vector3.Distance(transform.position, PlayerPosition);
    public Vector3 PlayerPosition => _player.position;

    private AIState _currentState;
    private Transform _player;

    private void Awake()
    {
        Agent = GetComponent<NavMeshAgent>();
    }

    private void Start()
    {
        _player = GameObject.FindWithTag("Player").transform;
        TransitionTo(_initialState);
    }

    public void TransitionTo(AIState newState)
    {
        _currentState?.Exit(this);
        _currentState = newState;
        _currentState.Enter(this);
    }

    private void Update() => _currentState?.Update(this);

    public void SetNextPatrolPoint()
    {
        // Pick next waypoint
    }
}
```

**Benefits:**
- Designers create AI variants by combining state assets (aggressive = short detection, fast chase; cautious = long detection, slow chase)
- New states = new SO class + asset, no modification to AIController
- States are reusable across different enemy types
- Easy to visualize: Inspector shows current state, each state shows its transition targets

**Gotcha:** SOs are shared assets. Do not store per-instance runtime data in the SO itself -- pass the `AIController` reference and store instance data there.

## Game State Machine

Top-level game flow management.

```csharp
public enum GameState { Boot, MainMenu, Loading, Playing, Paused, GameOver }

public class GameManager : MonoBehaviour
{
    private static GameManager _instance;
    public static GameManager Instance => _instance;

    public GameState CurrentState { get; private set; }
    public event Action<GameState, GameState> OnStateChanged; // old, new

    private void Awake()
    {
        if (_instance != null) { Destroy(gameObject); return; }
        _instance = this;
        DontDestroyOnLoad(gameObject);
    }

    public void SetState(GameState newState)
    {
        if (CurrentState == newState) return;

        GameState oldState = CurrentState;

        // Exit old state
        switch (oldState)
        {
            case GameState.Paused:
                Time.timeScale = 1f;
                break;
            case GameState.Playing:
                // Save checkpoint, etc.
                break;
        }

        CurrentState = newState;

        // Enter new state
        switch (newState)
        {
            case GameState.Paused:
                Time.timeScale = 0f;
                break;
            case GameState.GameOver:
                Time.timeScale = 0f;
                break;
            case GameState.Playing:
                Time.timeScale = 1f;
                break;
        }

        OnStateChanged?.Invoke(oldState, newState);
    }

    // Transition validation (optional but recommended)
    private static readonly Dictionary<GameState, GameState[]> ValidTransitions = new()
    {
        { GameState.Boot, new[] { GameState.MainMenu } },
        { GameState.MainMenu, new[] { GameState.Loading } },
        { GameState.Loading, new[] { GameState.Playing, GameState.MainMenu } },
        { GameState.Playing, new[] { GameState.Paused, GameState.GameOver, GameState.Loading } },
        { GameState.Paused, new[] { GameState.Playing, GameState.MainMenu } },
        { GameState.GameOver, new[] { GameState.MainMenu, GameState.Loading } },
    };

    public bool CanTransitionTo(GameState target)
    {
        return ValidTransitions.TryGetValue(CurrentState, out var valid)
            && System.Array.IndexOf(valid, target) >= 0;
    }
}
```

## AI State Machine Patterns

### Idle -> Patrol -> Chase -> Attack

The classic enemy AI loop.

```csharp
// State transition diagram:
//
//   Idle -----(timer)-----> Patrol
//     ^                       |
//     |                  (detect player)
//  (lose player)              |
//     |                       v
//   Patrol <--(lose)--- Chase
//                          |
//                     (in range)
//                          |
//                          v
//                       Attack ----(cooldown)----> Chase
//                          ^                         |
//                          +-------(in range)--------+

public class IdleState : IState
{
    private float _idleTimer;
    private readonly float _idleDuration;

    public void Enter() => _idleTimer = 0f;

    public void Update()
    {
        _idleTimer += Time.deltaTime;
        if (_idleTimer >= _idleDuration)
            _fsm.SetState<PatrolState>();
    }
}
```

### State with Transition Conditions

```csharp
// Reusable transition definition
[System.Serializable]
public class StateTransition
{
    public AIState TargetState;
    public enum Condition { PlayerInRange, PlayerOutOfRange, HealthBelow, TimerExpired }
    public Condition TriggerCondition;
    public float Threshold;
}

// State with declarative transitions
[CreateAssetMenu(menuName = "AI/States/Configurable State")]
public class ConfigurableAIState : AIState
{
    [SerializeField] private StateTransition[] _transitions;

    public override void Update(AIController ai)
    {
        foreach (var t in _transitions)
        {
            bool shouldTransition = t.TriggerCondition switch
            {
                StateTransition.Condition.PlayerInRange => ai.DistanceToPlayer < t.Threshold,
                StateTransition.Condition.PlayerOutOfRange => ai.DistanceToPlayer > t.Threshold,
                StateTransition.Condition.HealthBelow => ai.HealthPercent < t.Threshold,
                StateTransition.Condition.TimerExpired => ai.TimeInState > t.Threshold,
                _ => false,
            };

            if (shouldTransition)
            {
                ai.TransitionTo(t.TargetState);
                return;
            }
        }
    }
}
```

## Debugging State Machines

```csharp
// Add debug logging to your state machine
public class StateMachine
{
    public event Action<IState, IState> OnStateChanged;

    public void SetState<T>() where T : IState
    {
        // ... normal logic ...
        #if UNITY_EDITOR || DEVELOPMENT_BUILD
        Debug.Log($"[FSM] {_currentState?.GetType().Name ?? "null"} -> {newState.GetType().Name}");
        #endif
        OnStateChanged?.Invoke(_currentState, newState);
        // ... transition logic ...
    }
}

// Visual debugging in Inspector
public class FSMDebugDisplay : MonoBehaviour
{
    [SerializeField, ReadOnly] private string _currentStateName;
    [SerializeField, ReadOnly] private float _timeInState;

    private void Update()
    {
        _currentStateName = _fsm.CurrentState?.GetType().Name ?? "None";
        _timeInState += Time.deltaTime;
    }
}
```

## Choosing the Right Approach

| Factor | Animator FSM | Custom Code FSM | SO State FSM |
|--------|-------------|-----------------|--------------|
| Visual editing | Built-in visual graph | None (code only) | Inspector per state |
| Animation sync | Seamless | Manual | Manual |
| Testability | Hard (needs Animator) | Easy (pure C#) | Medium (needs SO instances) |
| Designer-friendly | Medium (complex UI) | No | Yes (drag-drop states) |
| State count | 3-8 | Any | Any |
| Complexity | Low-medium | High (but flexible) | Medium |
| Performance | Good | Best | Good |

**Recommendations:**
- **Character animation:** Animator FSM (it is designed for this)
- **Player controller logic:** Custom code FSM (testable, explicit)
- **AI behavior:** SO state FSM (designer-tunable, variant-friendly)
- **Game flow (menu/play/pause):** Simple enum + switch (under 6 states)
- **Complex AI with many conditions:** Consider a behavior tree instead
