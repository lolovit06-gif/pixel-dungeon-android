extends Node2D

const WORLD_SIZE := Vector2(1280, 720)
const PLAYER_SPEED := 175.0
const ENEMY_SPEED := 65.0
const JOYSTICK_RADIUS := 58.0
const JOYSTICK_DEADZONE := 10.0

var player_pos := Vector2(640, 360)
var enemy_positions: Array[Vector2] = [
    Vector2(430, 250),
    Vector2(800, 420),
    Vector2(920, 220),
    Vector2(360, 500)
]
var enemy_hp: Array[int] = [2, 2, 2, 2]
var attack_timer := 0.0
var attack_flash := 0.0
var player_hp := 5
var invulnerable_timer := 0.0
var message := "Move with joystick. Tap ATTACK to strike."
var floor_tiles: Array[Rect2] = []

var joystick_active := false
var joystick_touch_index := -1
var joystick_origin := Vector2(104, 0)
var joystick_vector := Vector2.ZERO
var attack_pressed := false
var attack_touch_index := -1
var screen_size := Vector2(640, 360)
var scale_factor := 1.0
var screen_offset := Vector2.ZERO

func _ready() -> void:
    randomize()
    for y in range(0, int(WORLD_SIZE.y), 32):
        for x in range(0, int(WORLD_SIZE.x), 32):
            floor_tiles.append(Rect2(x, y, 32, 32))
    _update_screen_transform()
    get_viewport().size_changed.connect(_update_screen_transform)
    queue_redraw()

func _update_screen_transform() -> void:
    screen_size = get_viewport_rect().size
    scale_factor = minf(screen_size.x / 640.0, screen_size.y / 360.0)
    screen_offset = (screen_size - Vector2(640, 360) * scale_factor) * 0.5
    queue_redraw()

func _screen_to_ui(p: Vector2) -> Vector2:
    return (p - screen_offset) / maxf(scale_factor, 0.001)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var ui_pos := _screen_to_ui(event.position)
        if event.pressed:
            if ui_pos.x < 230 and ui_pos.y > 150 and not joystick_active:
                joystick_active = true
                joystick_touch_index = event.index
                joystick_origin = ui_pos
                joystick_vector = Vector2.ZERO
            elif ui_pos.x > 500 and ui_pos.y > 245 and attack_touch_index == -1:
                attack_touch_index = event.index
                attack_pressed = true
        else:
            if event.index == joystick_touch_index:
                joystick_active = false
                joystick_touch_index = -1
                joystick_vector = Vector2.ZERO
            if event.index == attack_touch_index:
                attack_touch_index = -1
                attack_pressed = false
    elif event is InputEventScreenDrag:
        if event.index == joystick_touch_index:
            var ui_pos := _screen_to_ui(event.position)
            var delta := ui_pos - joystick_origin
            if delta.length() > JOYSTICK_RADIUS:
                delta = delta.normalized() * JOYSTICK_RADIUS
            joystick_vector = delta / JOYSTICK_RADIUS
            if joystick_vector.length() < JOYSTICK_DEADZONE / JOYSTICK_RADIUS:
                joystick_vector = Vector2.ZERO

func _process(delta: float) -> void:
    var direction := joystick_vector
    direction.x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    direction.y += Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
    if direction.length() > 1.0:
        direction = direction.normalized()
    player_pos += direction * PLAYER_SPEED * delta
    player_pos.x = clampf(player_pos.x, 20, WORLD_SIZE.x - 20)
    player_pos.y = clampf(player_pos.y, 20, WORLD_SIZE.y - 20)

    attack_timer = maxf(0.0, attack_timer - delta)
    attack_flash = maxf(0.0, attack_flash - delta)
    invulnerable_timer = maxf(0.0, invulnerable_timer - delta)

    if (attack_pressed or Input.is_action_pressed("attack")) and attack_timer <= 0.0:
        attack_timer = 0.42
        attack_flash = 0.14
        _attack()

    for i in range(enemy_positions.size()):
        if enemy_hp[i] <= 0:
            continue
        var to_player: Vector2 = player_pos - enemy_positions[i]
        if to_player.length() > 25:
            enemy_positions[i] += to_player.normalized() * ENEMY_SPEED * delta
        elif invulnerable_timer <= 0.0:
            player_hp -= 1
            invulnerable_timer = 0.8
            if player_hp <= 0:
                player_hp = 5
                player_pos = Vector2(640, 360)
                message = "You were defeated! Try again."
    if enemy_hp.count(0) == enemy_hp.size():
        message = "Room cleared! Enemies return."
        for i in range(enemy_hp.size()):
            enemy_hp[i] = 2
            enemy_positions[i] = Vector2(randf_range(150, 1130), randf_range(100, 620))
    queue_redraw()

func _attack() -> void:
    for i in range(enemy_positions.size()):
        if enemy_hp[i] > 0 and player_pos.distance_to(enemy_positions[i]) < 62:
            enemy_hp[i] -= 1
            if enemy_hp[i] <= 0:
                enemy_hp[i] = 0

func _draw() -> void:
    draw_set_transform(screen_offset, 0.0, Vector2(scale_factor, scale_factor))
    draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("#171d25"))

    var camera_origin := player_pos - Vector2(320, 180)
    camera_origin.x = clampf(camera_origin.x, 0, WORLD_SIZE.x - 640)
    camera_origin.y = clampf(camera_origin.y, 0, WORLD_SIZE.y - 360)
    draw_set_transform(screen_offset - camera_origin * scale_factor, 0.0, Vector2(scale_factor, scale_factor))
    for tile in floor_tiles:
        draw_rect(tile, Color("#292f38"))
        draw_rect(Rect2(tile.position + Vector2(1, 1), Vector2(30, 30)), Color("#303741"))
        if int(tile.position.x / 32 + tile.position.y / 32) % 3 == 0:
            draw_rect(Rect2(tile.position + Vector2(5, 7), Vector2(3, 3)), Color("#3c434d"))

    draw_rect(Rect2(0, 0, WORLD_SIZE.x, 18), Color("#59616b"))
    draw_rect(Rect2(0, WORLD_SIZE.y - 18, WORLD_SIZE.x, 18), Color("#59616b"))
    draw_rect(Rect2(0, 0, 18, WORLD_SIZE.y), Color("#59616b"))
    draw_rect(Rect2(WORLD_SIZE.x - 18, 0, 18, WORLD_SIZE.y), Color("#59616b"))

    for i in range(enemy_positions.size()):
        if enemy_hp[i] <= 0:
            continue
        var p := enemy_positions[i]
        draw_rect(Rect2(p + Vector2(-9, -7), Vector2(18, 17)), Color("#6e2934"))
        draw_rect(Rect2(p + Vector2(-7, -10), Vector2(14, 14)), Color("#b64b51"))
        draw_rect(Rect2(p + Vector2(-5, -5), Vector2(3, 3)), Color("#f4e6b5"))
        draw_rect(Rect2(p + Vector2(2, -5), Vector2(3, 3)), Color("#f4e6b5"))
        draw_rect(Rect2(p + Vector2(-10, -16), Vector2(20, 3)), Color("#171717"))
        draw_rect(Rect2(p + Vector2(-10, -16), Vector2(20.0 * enemy_hp[i] / 2.0, 3)), Color("#d94b4b"))

    draw_rect(Rect2(player_pos + Vector2(-9, 5), Vector2(18, 7)), Color("#12151a"))
    draw_rect(Rect2(player_pos + Vector2(-8, -8), Vector2(16, 20)), Color("#315b8a"))
    draw_rect(Rect2(player_pos + Vector2(-6, -13), Vector2(12, 12)), Color("#d9b28a"))
    draw_rect(Rect2(player_pos + Vector2(-7, -15), Vector2(14, 5)), Color("#c5cbd4"))
    draw_rect(Rect2(player_pos + Vector2(-4, -8), Vector2(3, 3)), Color("#20252d"))
    draw_rect(Rect2(player_pos + Vector2(2, -8), Vector2(3, 3)), Color("#20252d"))
    if attack_flash > 0.0:
        draw_rect(Rect2(player_pos + Vector2(10, -14), Vector2(22, 5)), Color("#f4e6b5"))
        draw_rect(Rect2(player_pos + Vector2(11, -16), Vector2(5, 9)), Color("#a9b4c1"))

    draw_set_transform(screen_offset, 0.0, Vector2(scale_factor, scale_factor))
    draw_rect(Rect2(12, 12, 218, 55), Color("#10151d"))
    draw_rect(Rect2(15, 15, 212, 49), Color("#343c47"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 35), "PIXEL DUNGEON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d9a1"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 54), "HP: " + "♥".repeat(player_hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ef7777"))
    draw_rect(Rect2(12, 76, 300, 24), Color("#10151d"))
    draw_string(ThemeDB.fallback_font, Vector2(20, 93), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e2e5e9"))

    var joy_center := Vector2(100, 286)
    draw_circle(joy_center, JOYSTICK_RADIUS, Color(0.1, 0.12, 0.15, 0.72))
    draw_arc(joy_center, JOYSTICK_RADIUS, 0, TAU, 32, Color("#aeb8c4"), 2.0)
    var knob_center := joy_center
    if joystick_active:
        knob_center = joy_center + joystick_vector * JOYSTICK_RADIUS
    draw_circle(knob_center, 24, Color(0.55, 0.62, 0.70, 0.85))
    draw_arc(knob_center, 24, 0, TAU, 24, Color("#e4e9ef"), 2.0)

    var attack_center := Vector2(565, 286)
    draw_circle(attack_center, 43, Color("#762f38") if attack_pressed else Color("#4b252e"))
    draw_arc(attack_center, 43, 0, TAU, 32, Color("#f1b7a6"), 2.0)
    draw_string(ThemeDB.fallback_font, attack_center + Vector2(-27, 5), "ATTACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff0d8"))

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
