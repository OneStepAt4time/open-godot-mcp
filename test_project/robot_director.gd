# ============================================================================
# robot_director.gd — single-scene animation director for the Kimi-robot demo.
# Target: Godot 4.7 editor, @tool (ticks inside the editor, no game run).
# Attach to the scene ROOT (Node3D).
#
# State machine. ALL motion is analytic in _process (accumulated clock); NO
# tweens, NO awaits — SceneTreeTween does not advance inside the editor.
#
#   STATE 0 "assembly" (0-18s): parts drop in from above, one group at a time,
#         each a 0.55s fall with an ease-out-back curve (~12% overshoot), in
#         choreographic order: floor, feet/legs, body, chest, arms, head,
#         eyes (with an emission flash), mouth, antenna, hands, sign.
#   STATE 1 "wake" (2s): head yaw right->left under a smooth envelope, plus
#         the first blink. Face parts orbit the head center and never detach.
#   STATE 2 "idle" (loop): sign+arm sway (+-0.08 rad / 2.2s), head bob
#         (+-0.03m / 3s, face follows), blink every ~3.7s (100ms), AntennaTip
#         emission pulse (1.5<->4.0 / 1.6s), ChestPanel "breathing"
#         (base+-0.4 / 2.7s), and a squash&stretch hop every ~6s
#         (scale.y 1 -> 0.88 -> 1.06 -> 1 in 0.45s, legs compensated).
#   STATE 3 "frozen": entered via set_frozen(true) or set_state(3). Motion
#         ramps to a full stop in 0.3s while the pose glides back to the exact
#         cached rest pose — this guarantees a clean re-cache after an
#         undo/redo detach/reattach (the cascade never saves the scene).
#
# Public API (call via execute_editor_script on the edited scene root):
#   root.set_state(0|1|2|3)     # jump to a state; 3 == freeze
#   root.set_frozen(true|false) # freeze / resume the interrupted state
#   root.get_state()            # current state index
#
# Robustness contract:
#   - get_node_or_null with plain String literals only (never &"StringName",
#     which parse-errors in combination with get_node_or_null).
#   - Rest transforms are cached once at boot (_ready, or lazily on the first
#     _process tick if _ready did not fire on an editor-time attach). Every
#     frame writes base + analytic offset, so there is zero drift over time.
#   - Missing or freed nodes are skipped silently; a partial scene animates.
#   - Do NOT save the scene while this script is animating: the current pose
#     would be baked in as the new rest pose.
# ============================================================================

@tool
extends Node3D

# ---- States -----------------------------------------------------------------

const STATE_ASSEMBLY := 0
const STATE_WAKE := 1
const STATE_IDLE := 2
const STATE_FROZEN := 3

# ---- Timing & motion tuning --------------------------------------------------

const ASSEMBLY_DURATION := 18.0  # total length of state 0
const DROP_DURATION := 0.55      # fall time per group
const FALL_HEIGHT := 7.0         # meters above the rest pose at drop start
const BACK_OVERSHOOT := 1.9      # ease-out-back constant -> ~12% overshoot
const DIP_MAX := 0.06            # soft cap for the below-rest landing dip (m)

const WAKE_DURATION := 2.0

# Scripted arc for the rendered trailer (game mode has no MCP cascade):
# after the first idle stretch, replay the full assembly once.
const REPLAY_AT := 42.0
const WAKE_YAW_AMP := 0.4        # rad, head yaw right->left
const WAKE_BLINK_AT := 0.9       # seconds into wake

const SWAY_AMPLITUDE := 0.08     # rad on rotation.z, sign group + arms
const SWAY_PERIOD := 2.2

const BOB_AMPLITUDE := 0.03      # meters on position.y, head group
const BOB_PERIOD := 3.0

const BLINK_PERIOD := 3.7        # seconds between blinks (idle)
const BLINK_JITTER := 0.3        # +-30% on the blink period
const BLINK_TOTAL := 0.10        # 100ms open->closed->open
const BLINK_CLOSE := 0.03        # seconds to fully close
const BLINK_HOLD := 0.04         # seconds spent fully closed
const BLINK_CLOSED_SCALE := 0.08 # scale.y multiplier while shut

const PULSE_MIN := 1.5           # AntennaTip emission_energy_multiplier range
const PULSE_MAX := 4.0
const PULSE_PERIOD := 1.6

const CHEST_PULSE_AMP := 0.4     # ChestPanel "breathing": base energy +- this
const CHEST_PULSE_PERIOD := 2.7  # non-harmonic with bob/sway/blink periods

const HOP_INTERVAL := 6.0        # seconds between hops (idle)
const HOP_JITTER := 0.2          # +-20% on the hop interval
const HOP_FIRST_DELAY := 4.0     # first hop happens this long after idle start
const HOP_DURATION := 0.45
const HOP_SQUASH := 0.88         # scale.y at the crouch
const HOP_STRETCH := 1.06        # scale.y at the rebound

const FREEZE_RAMP := 0.3         # seconds to freeze / unfreeze

const EYE_FLASH_ENERGY := 9.0    # emission flash peak when the eyes land
const EYE_FLASH_DECAY := 6.0     # exponential decay rate of the flash
const EYE_FLASH_TIME := 1.0      # flash window length (s)

# Choreographic drop order: [group node names, start time in seconds].
# Boring parts land quickly one after another; heroic parts (head, eyes,
# sign) get more air so the viewer can read them (benchmark P6).
const DROP_TABLE := [
	[["Floor"], 0.0],
	[["FootL", "FootR"], 1.3],
	[["LegL", "LegR"], 2.6],
	[["Body"], 3.95],
	[["ChestPanel"], 5.2],
	[["ArmL", "ArmR"], 6.5],
	[["Neck", "Head"], 8.1],
	[["EyeL", "EyeR"], 9.8],
	[["Mouth"], 11.3],
	[["Antenna", "AntennaTip"], 12.65],
	[["HandL", "HandR"], 14.0],
	[["SignBorder", "Sign", "SignLine1", "SignLine2"], 15.6],
]

# Idle/wake groups. Names are resolved once at cache time; missing nodes are
# simply skipped.
const SWAY_NAMES := ["SignBorder", "Sign", "SignLine1", "SignLine2", "ArmL", "ArmR"]
const BOB_NAMES := ["Head", "EyeL", "EyeR", "Mouth", "Antenna", "AntennaTip"]
const HEAD_ORBIT_NAMES := ["EyeL", "EyeR", "Mouth", "Antenna", "AntennaTip"]
const EYE_NAMES := ["EyeL", "EyeR"]
const HOP_LEG_NAMES := ["LegL", "LegR"]
const HOP_TRANSLATE_NAMES := [
	"ChestPanel", "Neck", "Head", "EyeL", "EyeR", "Mouth",
	"Antenna", "AntennaTip", "ArmL", "ArmR", "HandL", "HandR",
	"SignBorder", "Sign", "SignLine1", "SignLine2",
]

# ---- Runtime state -----------------------------------------------------------

var _state := STATE_ASSEMBLY
var _resume_state := STATE_ASSEMBLY  # state restored by set_frozen(false)

var _cached := false
var _time := 0.0          # scaled animation clock (stops on freeze)
var _state_time := 0.0    # seconds spent in the current state (scaled)

var _motion_scale := 1.0  # ramps 1 -> 0 on freeze, 0 -> 1 on resume
var _motion_target := 1.0
var _freeze_blend := 0.0  # 0 = fully animated pose, 1 = exact rest pose

# Node cache: name -> node, plus per-node rest transforms.
var _nodes := {}               # String -> Node3D
var _all: Array[Node3D] = []
var _base_pos := {}            # Node3D -> Vector3
var _base_rot := {}            # Node3D -> Vector3
var _base_scale := {}          # Node3D -> Vector3
var _half_h := {}              # Node3D -> float (0.0 when unknown)

var _drops: Array = []         # [{nodes: Array[Node3D], start: float}]
var _eyes_land_time := -1.0
var _flash_done := false

var _eye_mats: Array[StandardMaterial3D] = []
var _eye_base: Array[float] = []
var _antenna_mat: StandardMaterial3D = null
var _antenna_base := 2.5
var _chest_mat: StandardMaterial3D = null
var _chest_base := 2.5

# Blink / hop schedulers (driven by the scaled clock, no timers, no awaits).
var _blink_start := -1.0
var _next_blink_at := -1.0
var _blink_count := 0
var _hop_start := -1.0
var _next_hop_at := -1.0
var _hop_count := 0

# Camera keyframes, filled in _cache() (see the end of _cache).
var _cam_keys: Array = []

# Trailer arc: true after the one scripted assembly replay has fired.
var _replayed := false

# Per-frame offset accumulators: the idle state composes motions additively.
var _pos_off := {}             # Node3D -> Vector3
var _rot_off := {}             # Node3D -> Vector3
var _scale_mul := {}           # Node3D -> Vector3


func _ready() -> void:
	set_process(true)
	_boot()


func _process(delta: float) -> void:
	if not _cached:
		_boot()  # lazy fallback: _ready may not fire on an editor-time attach

	# Freeze ramps: the motion clock slows to a stop, the pose glides to rest.
	_motion_scale = move_toward(_motion_scale, _motion_target, delta / FREEZE_RAMP)
	var blend_target := 1.0 if _state == STATE_FROZEN else 0.0
	_freeze_blend = move_toward(_freeze_blend, blend_target, delta / FREEZE_RAMP)
	_time += delta * _motion_scale
	_state_time += delta * _motion_scale

	match _state:
		STATE_ASSEMBLY:
			_anim_assembly()
			if _state_time >= ASSEMBLY_DURATION:
				_enter_state(STATE_WAKE)
		STATE_WAKE:
			_anim_wake()
			if _state_time >= WAKE_DURATION:
				_enter_state(STATE_IDLE)
		STATE_IDLE:
			_anim_idle()
		STATE_FROZEN:
			_apply_freeze_hold()

	# Scripted trailer arc: replay the full assembly once after the first idle
	# stretch (in game mode there is no MCP undo/redo cascade to mimic it).
	if not _replayed and _state == STATE_IDLE and _time >= REPLAY_AT:
		_replayed = true
		_enter_state(STATE_ASSEMBLY)

	# While unfreezing, glide from the rest pose back into the animated pose.
	if _freeze_blend > 0.0 and _state != STATE_FROZEN:
		_blend_toward_rest()

	# Camera follows the choreography (paused while frozen).
	if _state != STATE_FROZEN:
		_anim_camera(delta)


# ---- Public API ---------------------------------------------------------------

# Jump to a state (0 assembly, 1 wake, 2 idle, 3 frozen). Resets the state
# clock. Safe to call via execute_editor_script on the edited scene root.
func set_state(n: int) -> void:
	if not _cached:
		_boot()
	if n == STATE_FROZEN:
		set_frozen(true)
		return
	_motion_target = 1.0
	_enter_state(clampi(n, STATE_ASSEMBLY, STATE_FROZEN))


# Freeze: stop all motion within FREEZE_RAMP seconds, gliding into the exact
# rest pose (and restoring base emission energies). Unfreeze: resume the
# interrupted state. Used around the undo/redo cascade so the robot holds a
# clean, re-cacheable pose.
func set_frozen(b: bool) -> void:
	if not _cached:
		_boot()
	if b:
		if _state == STATE_FROZEN:
			return
		_resume_state = _state
		_state = STATE_FROZEN
		_motion_target = 0.0
		print("[robot_director] frozen (resume state: %d)" % _resume_state)
	else:
		if _state != STATE_FROZEN:
			return
		_state = _resume_state
		_motion_target = 1.0
		print("[robot_director] unfrozen -> state %d" % _state)


func get_state() -> int:
	return _state


# ---- Boot & cache -------------------------------------------------------------

func _boot() -> void:
	if _cached:
		return  # idempotent: a late _ready must not re-cache an animated pose
	_cache()
	_enter_state(_state)


# Resolve every managed node once and store its rest transform. Nodes that are
# missing never join the show, so a partial scene still animates.
func _cache() -> void:
	_cached = true
	_nodes.clear()
	_all.clear()
	_base_pos.clear()
	_base_rot.clear()
	_base_scale.clear()
	_half_h.clear()
	_drops.clear()
	_eye_mats.clear()
	_eye_base.clear()
	_antenna_mat = null
	_chest_mat = null
	_eyes_land_time = -1.0
	_flash_done = false

	var names := {}
	for entry in DROP_TABLE:
		for nm in entry[0]:
			names[nm] = true
	for nm in SWAY_NAMES + BOB_NAMES + HEAD_ORBIT_NAMES + HOP_TRANSLATE_NAMES + HOP_LEG_NAMES:
		names[nm] = true

	for nm in names:
		var key := str(nm)
		var n := get_node_or_null(key) as Node3D
		if n == null:
			continue
		_nodes[key] = n
		_all.append(n)
		_base_pos[n] = n.position
		_base_rot[n] = n.rotation
		_base_scale[n] = n.scale
		_half_h[n] = _mesh_half_height(n)

	# Build the assembly drop schedule from the choreographic table.
	for entry in DROP_TABLE:
		var group_names: Array = entry[0]
		var nodes: Array[Node3D] = []
		for nm in group_names:
			var n := _node(str(nm))
			if n != null:
				nodes.append(n)
		_drops.append({"nodes": nodes, "start": float(entry[1])})
		if group_names.has("EyeL"):
			_eyes_land_time = float(entry[1]) + DROP_DURATION

	# Emission targets: eyes (landing flash) and antenna tip (idle pulse).
	for nm in EYE_NAMES:
		var n := _node(nm)
		if n == null:
			continue
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			continue
		_eye_mats.append(m)
		# Clamp the cached base energy: if a previous instance was frozen
		# mid-flash, do not adopt the flashed value as the new base.
		_eye_base.append(clampf(m.emission_energy_multiplier, 1.0, 3.0))

	var tip := _node("AntennaTip")
	if tip != null:
		var tmi := tip as MeshInstance3D
		if tmi != null:
			_antenna_mat = tmi.material_override as StandardMaterial3D
			if _antenna_mat != null:
				_antenna_base = clampf(_antenna_mat.emission_energy_multiplier, PULSE_MIN, PULSE_MAX)

	# Chest panel "breathing" target (art direction: base 2.5 +- 0.4).
	var chest := _node("ChestPanel")
	if chest != null:
		var cmi := chest as MeshInstance3D
		if cmi != null:
			_chest_mat = cmi.material_override as StandardMaterial3D
			if _chest_mat != null:
				_chest_base = clampf(_chest_mat.emission_energy_multiplier, 2.0, 3.0)

	print("[robot_director] cached %d nodes, %d drop groups, eyes: %d, antenna: %s, chest: %s"
		% [_all.size(), _drops.size(), _eye_mats.size(),
		   "OK" if _antenna_mat != null else "missing",
		   "OK" if _chest_mat != null else "missing"])

	# Camera choreography (drives the EDITOR viewport camera, so the recording
	# stays framed no matter how slowly MCP commands trickle in).
	# [show_time, position, look_at] — show_time is the scaled _time clock.
	_cam_keys = [
		[0.0, Vector3(1.2, 3.3, 5.9), Vector3(0, 2.8, 0)],
		[8.0, Vector3(0.5, 3.0, 1.9), Vector3(0, 2.9, 0.15)],
		[14.5, Vector3(-1.4, 3.3, 5.7), Vector3(0, 2.85, 0)],
		[21.0, Vector3(1.6, 1.5, 6.2), Vector3(0, 3.0, 0)],
	]


# Safe node lookup: never errors on missing or freed nodes.
func _node(nm: String) -> Node3D:
	var v: Variant = _nodes.get(nm, null)
	if v == null:
		return null
	if not is_instance_valid(v):
		return null
	return v as Node3D


# ---- Camera choreography ----------------------------------------------------

# Latest keyframe target at the given show time (holds between keyframes).
func _camera_target(t: float) -> Array:
	var pos: Vector3 = _cam_keys[0][1]
	var look: Vector3 = _cam_keys[0][2]
	for k in _cam_keys:
		if t < k[0]:
			break
		pos = k[1]
		look = k[2]
	return [pos, look]


# Glide the editor viewport camera toward the current keyframe target.
func _anim_camera(delta: float) -> void:
	if _cam_keys.is_empty():
		return
	# Never hijack the user's editor camera; the choreography only drives the
	# in-game MainCamera (used for the README trailer via Movie Maker mode).
	if Engine.is_editor_hint():
		return
	var cam := get_node_or_null("MainCamera") as Camera3D
	if cam == null:
		return
	var target = _camera_target(_time)
	cam.global_position = cam.global_position.lerp(target[0], 1.0 - exp(-2.5 * delta))
	cam.look_at(target[1], Vector3.UP)


# Half-height of a node's mesh in world units (0.0 when unknown). Used to keep
# the bottom edge planted while scaling Y (squash & stretch anchoring).
# Supports every primitive used by the current art direction (robot_parts.json
# take 10: SphereMesh / CapsuleMesh / CylinderMesh / BoxMesh).
func _mesh_half_height(n: Node3D) -> float:
	var mi := n as MeshInstance3D
	if mi == null:
		return 0.0
	var h := 0.0
	var bm := mi.mesh as BoxMesh
	if bm != null:
		h = bm.size.y
	else:
		var sm := mi.mesh as SphereMesh
		if sm != null:
			h = sm.height
		else:
			var cm := mi.mesh as CapsuleMesh
			if cm != null:
				h = cm.height
			else:
				var cym := mi.mesh as CylinderMesh
				if cym != null:
					h = cym.height
	if h == 0.0:
		return 0.0
	var bs: Vector3 = _base_scale[n]
	return 0.5 * h * bs.y


# ---- State machine --------------------------------------------------------------

func _enter_state(n: int) -> void:
	_state = n
	_state_time = 0.0
	match n:
		STATE_ASSEMBLY:
			# Empty stage: every part hides until its own drop starts.
			_flash_done = false
			_blink_start = -1.0
			_next_blink_at = -1.0
			_hop_start = -1.0
			_next_hop_at = -1.0
			for node in _all:
				if is_instance_valid(node):
					node.visible = false
		STATE_WAKE, STATE_IDLE:
			# From wake onward the whole robot is on stage.
			for node in _all:
				if is_instance_valid(node):
					node.visible = true
			_restore_emissions()
			if n == STATE_WAKE:
				_next_blink_at = _time + WAKE_BLINK_AT
			else:
				if _next_blink_at <= _time:
					_next_blink_at = _time + 1.2
				_next_hop_at = _time + HOP_FIRST_DELAY
	print("[robot_director] state -> %d" % n)


# ---- State 0: assembly ------------------------------------------------------------

func _anim_assembly() -> void:
	for d in _drops:
		var nodes: Array[Node3D] = d["nodes"]
		var start: float = d["start"]
		var local := _state_time - start
		if local < 0.0:
			# Not its turn yet: keep it hidden.
			for node in nodes:
				if is_instance_valid(node):
					node.visible = false
			continue
		if local >= DROP_DURATION:
			# Landed: pin it to the exact rest pose.
			for node in nodes:
				if not is_instance_valid(node):
					continue
				node.visible = true
				var bp: Vector3 = _base_pos[node]
				var br: Vector3 = _base_rot[node]
				var bs: Vector3 = _base_scale[node]
				node.position = bp
				node.rotation = br
				node.scale = bs
			continue
		# Falling: ease-out-back drives both the drop and the elastic pop-in.
		var p := _ease_out_back(local / DROP_DURATION)
		var h := FALL_HEIGHT * (1.0 - p)
		if h < 0.0:
			# The back curve overshoots ~12% of the fall height; soft-cap the
			# dip so parts settle into the floor instead of clipping through.
			h = DIP_MAX * tanh(h / DIP_MAX)
		var pop := maxf(0.001, p)
		for node in nodes:
			if not is_instance_valid(node):
				continue
			node.visible = true
			var bp2: Vector3 = _base_pos[node]
			var bs2: Vector3 = _base_scale[node]
			node.position = bp2 + Vector3(0.0, h, 0.0)
			node.scale = bs2 * pop

	# Eyes landing flash: an emission spike that decays back to base energy.
	if not _flash_done and _eyes_land_time >= 0.0:
		var ft := _state_time - _eyes_land_time
		if ft >= EYE_FLASH_TIME:
			_restore_eyes()
			_flash_done = true
		elif ft >= 0.0:
			var e := EYE_FLASH_ENERGY * exp(-EYE_FLASH_DECAY * ft)
			for i in _eye_mats.size():
				_eye_mats[i].emission_energy_multiplier = maxf(_eye_base[i], e)


# ---- State 1: wake -----------------------------------------------------------------

func _anim_wake() -> void:
	_update_blinks()
	var t := _state_time / WAKE_DURATION
	# Smooth envelope so the yaw eases in and out instead of snapping.
	var env := smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.8, 1.0, t))
	var yaw := WAKE_YAW_AMP * sin(TAU * _state_time / WAKE_DURATION) * env

	var driven := {}
	var head := _node("Head")
	var hc := Vector3.ZERO
	if head != null:
		var bph: Vector3 = _base_pos[head]
		var brh: Vector3 = _base_rot[head]
		hc = bph
		head.position = bph
		head.rotation = brh + Vector3(0.0, yaw, 0.0)
		driven[head] = true

	# Face parts orbit the head center so they never detach during the yaw.
	var cy := cos(yaw)
	var sy := sin(yaw)
	for nm in HEAD_ORBIT_NAMES:
		var node := _node(nm)
		if node == null:
			continue
		var bp: Vector3 = _base_pos[node]
		var br: Vector3 = _base_rot[node]
		var off := bp - hc
		node.position = hc + Vector3(off.x * cy + off.z * sy, off.y, -off.x * sy + off.z * cy)
		node.rotation = br + Vector3(0.0, yaw, 0.0)
		driven[node] = true

	# The first blink, partway through the head turn.
	var b := _blink_scale()
	if b < 1.0:
		for nm in EYE_NAMES:
			var node := _node(nm)
			if node == null:
				continue
			var bs: Vector3 = _base_scale[node]
			node.scale = Vector3(bs.x, bs.y * b, bs.z)

	# Everything else holds the rest pose: the stage is still, the head acts.
	for node in _all:
		if not is_instance_valid(node):
			continue
		if driven.has(node):
			continue
		var bp3: Vector3 = _base_pos[node]
		var br3: Vector3 = _base_rot[node]
		var bs3: Vector3 = _base_scale[node]
		node.position = bp3
		node.rotation = br3
		node.scale = bs3


# ---- State 2: idle -------------------------------------------------------------------

func _anim_idle() -> void:
	_update_blinks()
	_update_hop()
	_pos_off.clear()
	_rot_off.clear()
	_scale_mul.clear()

	# Sign + raised arms sway together, all in phase.
	var sway := SWAY_AMPLITUDE * sin(TAU * _time / SWAY_PERIOD)
	for nm in SWAY_NAMES:
		var node := _node(nm)
		if node != null:
			_add_rot(node, Vector3(0.0, 0.0, sway))

	# Head micro-bob; eyes, mouth and antenna follow so nothing detaches.
	var bob := BOB_AMPLITUDE * sin(TAU * _time / BOB_PERIOD)
	for nm in BOB_NAMES:
		var node := _node(nm)
		if node != null:
			_add_pos(node, Vector3(0.0, bob, 0.0))

	# Personality hop: squash & stretch with compensated legs.
	if _hop_start >= 0.0:
		_apply_hop(_hop_factor(_time - _hop_start))

	# Periodic blink.
	var b := _blink_scale()
	if b < 1.0:
		for nm in EYE_NAMES:
			var node := _node(nm)
			if node != null:
				_mul_scale(node, Vector3(1.0, b, 1.0))

	_commit_pose()

	# Antenna tip emission pulse.
	if _antenna_mat != null:
		var w := 0.5 + 0.5 * sin(TAU * _time / PULSE_PERIOD)
		_antenna_mat.emission_energy_multiplier = lerpf(PULSE_MIN, PULSE_MAX, w)

	# Chest panel "breathing" (art direction: base energy +- 0.4).
	if _chest_mat != null:
		_chest_mat.emission_energy_multiplier = _chest_base + CHEST_PULSE_AMP * sin(TAU * _time / CHEST_PULSE_PERIOD)


# Squash & stretch envelope: 1 -> HOP_SQUASH -> HOP_STRETCH -> 1 over
# HOP_DURATION (0.45s), smoothstepped at every joint.
func _hop_factor(t: float) -> float:
	if t < 0.0 or t >= HOP_DURATION:
		return 1.0
	var a := HOP_DURATION / 3.0
	if t < a:
		return lerpf(1.0, HOP_SQUASH, smoothstep(0.0, a, t))
	if t < 2.0 * a:
		return lerpf(HOP_SQUASH, HOP_STRETCH, smoothstep(a, 2.0 * a, t))
	return lerpf(HOP_STRETCH, 1.0, smoothstep(2.0 * a, HOP_DURATION, t))


func _apply_hop(hs: float) -> void:
	# Body squashes about its bottom edge (it sits on the legs).
	var body := _node("Body")
	var body_h := 0.0
	if body != null:
		body_h = 2.0 * float(_half_h.get(body, 0.0))
		_mul_scale(body, Vector3(1.0, hs, 1.0))
		_add_pos(body, Vector3(0.0, -(1.0 - hs) * 0.5 * body_h, 0.0))
	# Legs compensate inversely: feet stay planted, total height is conserved.
	var s_leg := clampf(2.0 - hs, 0.85, 1.15)
	for nm in HOP_LEG_NAMES:
		var node := _node(nm)
		if node == null:
			continue
		_mul_scale(node, Vector3(1.0, s_leg, 1.0))
		_add_pos(node, Vector3(0.0, -(1.0 - s_leg) * float(_half_h.get(node, 0.0)), 0.0))
	# The whole upper stack (and the held sign) follows the body top.
	var dy := -(1.0 - hs) * body_h
	if dy != 0.0:
		for nm in HOP_TRANSLATE_NAMES:
			var node := _node(nm)
			if node != null:
				_add_pos(node, Vector3(0.0, dy, 0.0))


# ---- Schedulers ------------------------------------------------------------------------

func _update_blinks() -> void:
	if _blink_start >= 0.0 and _time - _blink_start >= BLINK_TOTAL:
		_blink_start = -1.0
		_next_blink_at = _time + BLINK_PERIOD * (1.0 + _jitter(_blink_count, BLINK_JITTER))
		_blink_count += 1
	if _blink_start < 0.0 and _next_blink_at >= 0.0 and _time >= _next_blink_at:
		_blink_start = _time


# 1.0 while open, BLINK_CLOSED_SCALE while shut. Fully deterministic in _time.
func _blink_scale() -> float:
	if _blink_start < 0.0:
		return 1.0
	var t := _time - _blink_start
	if t < 0.0 or t >= BLINK_TOTAL:
		return 1.0
	if t < BLINK_CLOSE:
		return lerpf(1.0, BLINK_CLOSED_SCALE, smoothstep(0.0, BLINK_CLOSE, t))
	if t < BLINK_CLOSE + BLINK_HOLD:
		return BLINK_CLOSED_SCALE
	return lerpf(BLINK_CLOSED_SCALE, 1.0,
		smoothstep(BLINK_CLOSE + BLINK_HOLD, BLINK_TOTAL, t))


func _update_hop() -> void:
	if _hop_start >= 0.0:
		if _time - _hop_start >= HOP_DURATION:
			_hop_start = -1.0
			_next_hop_at = _time + HOP_INTERVAL * (1.0 + _jitter(_hop_count, HOP_JITTER))
			_hop_count += 1
	elif _next_hop_at >= 0.0 and _time >= _next_hop_at:
		_hop_start = _time


# Deterministic pseudo-random in [-amount, +amount] from an integer seed.
func _jitter(index: int, amount: float) -> float:
	var h := fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)
	return (h * 2.0 - 1.0) * amount


# ---- Freeze & rest pose -----------------------------------------------------------------

func _apply_freeze_hold() -> void:
	_blend_toward_rest()
	if _freeze_blend >= 0.999:
		_restore_emissions()


# Lerp every managed node from its current pose toward the cached rest pose.
func _blend_toward_rest() -> void:
	if _freeze_blend <= 0.0:
		return
	for node in _all:
		if not is_instance_valid(node):
			continue
		var bp: Vector3 = _base_pos[node]
		var br: Vector3 = _base_rot[node]
		var bs: Vector3 = _base_scale[node]
		node.position = node.position.lerp(bp, _freeze_blend)
		node.rotation = node.rotation.lerp(br, _freeze_blend)
		node.scale = node.scale.lerp(bs, _freeze_blend)


func _restore_emissions() -> void:
	_restore_eyes()
	if _antenna_mat != null:
		_antenna_mat.emission_energy_multiplier = _antenna_base
	if _chest_mat != null:
		_chest_mat.emission_energy_multiplier = _chest_base


func _restore_eyes() -> void:
	for i in _eye_mats.size():
		_eye_mats[i].emission_energy_multiplier = _eye_base[i]


# ---- Offset accumulation & commit ---------------------------------------------------------

func _add_pos(n: Node3D, v: Vector3) -> void:
	var cur: Vector3 = _pos_off.get(n, Vector3.ZERO)
	_pos_off[n] = cur + v


func _add_rot(n: Node3D, v: Vector3) -> void:
	var cur: Vector3 = _rot_off.get(n, Vector3.ZERO)
	_rot_off[n] = cur + v


func _mul_scale(n: Node3D, v: Vector3) -> void:
	var cur: Vector3 = _scale_mul.get(n, Vector3.ONE)
	_scale_mul[n] = cur * v


func _commit_pose() -> void:
	for node in _all:
		if not is_instance_valid(node):
			continue
		var bp: Vector3 = _base_pos[node]
		var br: Vector3 = _base_rot[node]
		var bs: Vector3 = _base_scale[node]
		var po: Vector3 = _pos_off.get(node, Vector3.ZERO)
		var ro: Vector3 = _rot_off.get(node, Vector3.ZERO)
		var sm: Vector3 = _scale_mul.get(node, Vector3.ONE)
		node.position = bp + po
		node.rotation = br + ro
		node.scale = bs * sm


# ---- Easing --------------------------------------------------------------------------------

# Ease-out-back with BACK_OVERSHOOT (c1 ~= 1.9 gives a ~12% curve overshoot).
func _ease_out_back(x: float) -> float:
	var u := x - 1.0
	return 1.0 + (BACK_OVERSHOOT + 1.0) * u * u * u + BACK_OVERSHOOT * u * u
