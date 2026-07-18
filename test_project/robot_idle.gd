# ============================================================================
# robot_idle.gd — looping idle animation for the Kimi-robot demo scene.
# Target: Godot 4.7 editor, @tool (ticks inside the editor, no game run).
# Attach to the scene ROOT (Node3D) of the test_project robot scene.
#
# ATTACH VIA MCP (open-godot-mcp), two calls:
#   1) Write this file into the project:
#      {"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"create_script","arguments":{"path":"res://robot_idle.gd","content":"<full contents of this file, JSON-escaped: \\n for newlines, \" for quotes>"}}}
#   2) Attach it to the scene root (node_path "." = edited scene root):
#      {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"attach_script","arguments":{"node_path":".","script_path":"res://robot_idle.gd"}}}
#   Watch the editor Output dock for "[robot_idle] cached: ..." — that line
#   confirms the script is alive and ticking. Do NOT save the scene while the
#   animation runs (it would bake the current pose in as the new rest pose).
#
# DESIGN NOTES:
#   - No tween/await: SceneTreeTween does not advance in the editor. All
#     motion is analytic (sine of accumulated _time), so the loop is
#     deterministic and framerate-independent.
#   - Rest transforms are captured once on the first tick; every frame writes
#     value = base + offset, so there is zero drift over time.
#   - Missing nodes are skipped silently (get_node_or_null at cache time).
# ============================================================================

@tool
extends Node3D

# ---- Tuning ---------------------------------------------------------------

const SWAY_AMPLITUDE := 0.08   # rad on rotation.z, sign group + arms
const SWAY_PERIOD := 2.2       # seconds per sway cycle

const BLINK_PERIOD := 3.5      # seconds between blink starts
const BLINK_TOTAL := 0.12      # seconds from fully open back to fully open
const BLINK_CLOSE_TIME := 0.03 # seconds to reach fully closed
const BLINK_HOLD_TIME := 0.06  # seconds spent fully closed
const BLINK_CLOSED := 0.05     # scale.y multiplier while closed
const BLINK_OFFSET := 2.0      # keeps eyes open right after attach; first
                               # blink happens at _time ~= 1.5s

const PULSE_MIN := 1.5         # emission_energy_multiplier range
const PULSE_MAX := 4.0
const PULSE_PERIOD := 1.6      # seconds per antenna pulse cycle

const BOB_AMPLITUDE := 0.03    # meters on position.y, head group
const BOB_PERIOD := 3.0        # seconds per bob cycle

# Periods are intentionally non-harmonic (2.2 / 1.6 / 3.0 / 3.5) so the
# combined motion never visibly repeats and reads as organic idle.

# ---- State ----------------------------------------------------------------

var _time := 0.0
var _cached := false

var _sway_group: Array[Node3D] = [] # SignBorder, Sign, SignLine1, SignLine2, ArmL, ArmR
var _bob_group: Array[Node3D] = []  # Head, EyeL, EyeR, Mouth, Antenna, AntennaTip
var _eyes: Array[Node3D] = []       # EyeL, EyeR
var _antenna_mat: StandardMaterial3D = null

var _base_rot_z := {}   # Node3D -> float
var _base_pos_y := {}   # Node3D -> float
var _base_scale_y := {} # Node3D -> float


func _ready() -> void:
	_cache()


func _process(delta: float) -> void:
	if not _cached:
		_cache() # lazy fallback: _ready may not fire on a runtime attach
	_time += delta
	_apply_animation()


# Resolve every node once and store its rest transform. Nodes that are not
# found simply never join a group, so a partial scene still animates.
func _cache() -> void:
	_cached = true
	_sway_group.clear()
	_bob_group.clear()
	_eyes.clear()
	_base_rot_z.clear()
	_base_pos_y.clear()
	_base_scale_y.clear()

	# (a)+(b) sign assembly and raised arms share the exact same angle.
	for node_name in ["SignBorder", "Sign", "SignLine1", "SignLine2", "ArmL", "ArmR"]:
		var n := get_node_or_null(node_name) as Node3D
		if n == null:
			continue
		_sway_group.append(n)
		_base_rot_z[n] = n.rotation.z

	# (e) Antenna/AntennaTip bob with the head so the antenna never detaches.
	for node_name in ["Head", "EyeL", "EyeR", "Mouth", "Antenna", "AntennaTip"]:
		var n := get_node_or_null(node_name) as Node3D
		if n == null:
			continue
		_bob_group.append(n)
		_base_pos_y[n] = n.position.y

	# (c) blink targets.
	for node_name in ["EyeL", "EyeR"]:
		var n := get_node_or_null(node_name) as Node3D
		if n == null:
			continue
		_eyes.append(n)
		_base_scale_y[n] = n.scale.y

	# (d) emission pulse target (material_override must be StandardMaterial3D).
	_antenna_mat = null
	var tip := get_node_or_null("AntennaTip") as Node3D
	if tip != null:
		_antenna_mat = tip.material_override as StandardMaterial3D

	print("[robot_idle] cached: %d sway, %d bob, %d eyes, antenna material: %s"
		% [_sway_group.size(), _bob_group.size(), _eyes.size(),
		   "OK" if _antenna_mat != null else "missing"])


func _apply_animation() -> void:
	# (a)+(b) Sign and arms sway together on rotation.z, all in phase.
	var sway := SWAY_AMPLITUDE * sin(TAU * _time / SWAY_PERIOD)
	for n in _sway_group:
		n.rotation.z = _base_rot_z[n] + sway

	# (e) Head micro-bob on position.y; eyes, mouth and antenna follow.
	var bob := BOB_AMPLITUDE * sin(TAU * _time / BOB_PERIOD)
	for n in _bob_group:
		n.position.y = _base_pos_y[n] + bob

	# (c) Both eyes blink together: fast close, short hold, fast reopen.
	var blink := _blink_scale()
	for n in _eyes:
		n.scale.y = _base_scale_y[n] * blink

	# (d) Antenna tip pulses its emission energy.
	if _antenna_mat != null:
		var w := 0.5 + 0.5 * sin(TAU * _time / PULSE_PERIOD)
		_antenna_mat.emission_energy_multiplier = lerpf(PULSE_MIN, PULSE_MAX, w)


# Returns 1.0 when open, BLINK_CLOSED while shut. Piecewise-smooth and fully
# deterministic (function of _time only).
func _blink_scale() -> float:
	var phase := fposmod(_time + BLINK_OFFSET, BLINK_PERIOD)
	if phase < BLINK_CLOSE_TIME:
		return lerpf(1.0, BLINK_CLOSED, smoothstep(0.0, BLINK_CLOSE_TIME, phase))
	if phase < BLINK_CLOSE_TIME + BLINK_HOLD_TIME:
		return BLINK_CLOSED
	if phase < BLINK_TOTAL:
		return lerpf(BLINK_CLOSED, 1.0,
			smoothstep(BLINK_CLOSE_TIME + BLINK_HOLD_TIME, BLINK_TOTAL, phase))
	return 1.0
