extends Node2D

const Audio := preload("res://scripts/orbit_audio.gd")
const SIZE := Vector2(960, 540)
const PLAYER_SPEED := 260.0
const PLAYER_RADIUS := 15.0
const ORB_RADIUS := 10.0
const DRONE_RADIUS := 16.0
const DASH_DURATION := 0.16
const DASH_SPEED := 680.0
const DASH_RECHARGE := 2.0
const RECHARGE_REDUCTION := 0.30
const MAGNET_BONUS := 12.0

enum Upgrade { RECHARGE, MAGNET, SHIELD }
const TARGETS := [10, 15, 20, 25, 30]
const DRONE_COUNTS := [3, 4, 5, 6, 8]

var player_pos := SIZE / 2.0
var orbs: Array[Vector2] = []
var drones: Array[Dictionary] = []
var level := 0
var score := 0
var total_score := 0
var lives := 3
var state := "menu"
var hit_cooldown := 0.0
var dash_direction := Vector2.RIGHT
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_requested := false
var recharge_upgrades := 0
var magnet_upgrades := 0
var shield_charges := 0
var rng := RandomNumberGenerator.new()
var hud: Label
var overlay: ColorRect
var card: VBoxContainer
var mute_button: Button
var audio := Audio.new()

func _ready() -> void:
    rng.randomize()
    add_child(audio)
    hud = Label.new()
    hud.position = Vector2(18, 9)
    hud.add_theme_font_size_override("font_size", 22)
    add_child(hud)

    overlay = ColorRect.new()
    overlay.size = SIZE
    overlay.color = Color("#09101cdd")
    add_child(overlay)
    var center := CenterContainer.new()
    center.size = SIZE
    overlay.add_child(center)
    card = VBoxContainer.new()
    card.add_theme_constant_override("separation", 12)
    card.custom_minimum_size.x = 490
    center.add_child(card)

    mute_button = Button.new()
    mute_button.position = Vector2(801, 7)
    mute_button.size = Vector2(144, 34)
    mute_button.focus_mode = Control.FOCUS_NONE
    mute_button.pressed.connect(toggle_audio)
    add_child(mute_button)
    update_audio_label()
    show_menu()

func show_screen(title: String, detail: String) -> void:
    for child in card.get_children():
        card.remove_child(child)
        child.queue_free()
    var heading := Label.new()
    heading.text = title
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 38)
    heading.modulate = Color("#80ffda")
    card.add_child(heading)
    var body := Label.new()
    body.text = detail
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.add_theme_font_size_override("font_size", 19)
    card.add_child(body)
    overlay.show()
    queue_redraw()

func add_screen_button(label: String, action: Callable) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size.y = 42
    card.add_child(button)
    button.pressed.connect(action)
    if card.get_child_count() == 3:
        button.grab_focus()

func show_menu() -> void:
    state = "menu"
    hud.hide()
    audio.music.stop()
    audio.effects.stop()
    show_screen("ORBIT COLLECTOR", "Collect gold orbs. Dodge pink drones.")
    add_screen_button("Start Game", restart)
    add_screen_button("How to Play", show_help)

func show_help() -> void:
    state = "help"
    show_screen("HOW TO PLAY",
        "Move with WASD or the arrow keys.\nTouch gold orbs to collect them. Avoid pink drones.\nPress Space to dash safely through drones.\nChoose an upgrade between sectors.\nReach the orb target in each of five sectors.\nYou have three lives for the entire run.\n\nM toggles audio. R restarts a run.\nEsc returns to the main menu and ends the run.")
    add_screen_button("Back to Main Menu", show_menu)

func toggle_audio() -> void:
    audio.toggle()
    update_audio_label()

func update_audio_label() -> void:
    mute_button.text = "Sound off [M]" if audio.muted else "Sound on [M]"

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if event.physical_keycode == KEY_M:
        toggle_audio()
    elif event.physical_keycode == KEY_R and state in ["playing", "clear", "won", "lost"]:
        restart()
    elif event.physical_keycode == KEY_SPACE and state == "playing":
        dash_requested = true
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE:
        show_menu()

func restart() -> void:
    level = 0
    total_score = 0
    lives = 3
    recharge_upgrades = 0
    magnet_upgrades = 0
    shield_charges = 0
    audio.effects.stop()
    start_level()

func choose_upgrade(upgrade: Upgrade) -> void:
    if state != "clear":
        return
    match upgrade:
        Upgrade.RECHARGE:
            recharge_upgrades += 1
        Upgrade.MAGNET:
            magnet_upgrades += 1
        Upgrade.SHIELD:
            shield_charges += 1
    level += 1
    start_level()

func start_level() -> void:
    player_pos = SIZE / 2.0
    score = 0
    state = "playing"
    hit_cooldown = 0.0
    dash_direction = Vector2.RIGHT
    dash_time = 0.0
    dash_cooldown = 0.0
    dash_requested = false
    orbs.clear()
    drones.clear()
    for i in range(5):
        orbs.append(random_point())
    for i in range(DRONE_COUNTS[level]):
        var pos := random_point()
        while pos.distance_to(player_pos) < 115.0:
            pos = random_point()
        var speed := rng.randf_range(90.0, 145.0) + level * 18.0
        drones.append({"position": pos, "velocity": Vector2.RIGHT.rotated(rng.randf_range(0, TAU)) * speed})
    overlay.hide()
    hud.show()
    audio.start_music()
    update_hud()
    queue_redraw()

func random_point() -> Vector2:
    return Vector2(rng.randf_range(40.0, SIZE.x - 40.0), rng.randf_range(60.0, SIZE.y - 40.0))

func _process(delta: float) -> void:
    if state != "playing":
        return

    var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if Input.is_key_pressed(KEY_A): direction.x -= 1.0
    if Input.is_key_pressed(KEY_D): direction.x += 1.0
    if Input.is_key_pressed(KEY_W): direction.y -= 1.0
    if Input.is_key_pressed(KEY_S): direction.y += 1.0
    direction = direction.limit_length(1.0)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    if dash_time <= 0.0 and direction != Vector2.ZERO:
        dash_direction = direction.normalized()
    if dash_requested and dash_cooldown <= 0.0:
        dash_time = DASH_DURATION
        dash_cooldown = DASH_RECHARGE - recharge_upgrades * RECHARGE_REDUCTION
    dash_requested = false
    var dash_step := minf(delta, dash_time)
    dash_time -= dash_step
    player_pos += dash_direction * DASH_SPEED * dash_step
    player_pos += direction * PLAYER_SPEED * (delta - dash_step)
    player_pos = player_pos.clamp(Vector2(PLAYER_RADIUS, PLAYER_RADIUS + 35), SIZE - Vector2(PLAYER_RADIUS, PLAYER_RADIUS))

    for i in range(orbs.size() - 1, -1, -1):
        if player_pos.distance_to(orbs[i]) < PLAYER_RADIUS + ORB_RADIUS + magnet_upgrades * MAGNET_BONUS:
            orbs[i] = random_point()
            score += 1
            total_score += 1
            if score >= TARGETS[level]:
                finish(true)
                return
            audio.play_cue("collect")

    hit_cooldown = maxf(0.0, hit_cooldown - delta)
    for drone in drones:
        var pos: Vector2 = drone["position"]
        var velocity: Vector2 = drone["velocity"]
        pos += velocity * delta
        if pos.x < DRONE_RADIUS or pos.x > SIZE.x - DRONE_RADIUS:
            velocity.x *= -1.0
            pos.x = clampf(pos.x, DRONE_RADIUS, SIZE.x - DRONE_RADIUS)
        if pos.y < 48 + DRONE_RADIUS or pos.y > SIZE.y - DRONE_RADIUS:
            velocity.y *= -1.0
            pos.y = clampf(pos.y, 48 + DRONE_RADIUS, SIZE.y - DRONE_RADIUS)
        drone["position"] = pos
        drone["velocity"] = velocity
        if dash_step <= 0.0 and hit_cooldown <= 0.0 and player_pos.distance_to(pos) < PLAYER_RADIUS + DRONE_RADIUS:
            hit_cooldown = 1.3
            if shield_charges > 0:
                shield_charges -= 1
                audio.play_cue("shield")
                continue
            lives -= 1
            if lives <= 0:
                finish(false)
                return
            audio.play_cue("hit")
    update_hud()
    queue_redraw()

func update_hud() -> void:
    var dash_status := "Ready" if dash_cooldown <= 0.0 else "%.1fs" % dash_cooldown
    hud.text = "Sector %d/%d    Orbs %d/%d    Lives %d    Score %d    Dash %s    Shield %d" % [
        level + 1, TARGETS.size(), score, TARGETS[level], lives, total_score, dash_status, shield_charges
    ]

func finish(won: bool) -> void:
    update_hud()
    audio.music.stop()
    if not won:
        state = "lost"
        audio.play_cue("loss")
        show_screen("GAME OVER", "Sector %d reached  •  %d orbs collected" % [level + 1, total_score])
    elif level == TARGETS.size() - 1:
        state = "won"
        audio.play_cue("win")
        show_screen("YOU WIN", "All five sectors cleared  •  %d orbs collected" % total_score)
    else:
        state = "clear"
        audio.play_cue("clear")
        show_screen("SECTOR %d CLEARED" % (level + 1), "%d lives remaining  •  %d orbs collected\nChoose one upgrade to continue" % [lives, total_score])
        add_screen_button("Quick Recharge   |   Dash recharges 0.3s sooner", choose_upgrade.bind(Upgrade.RECHARGE))
        add_screen_button("Orb Magnet   |   Pickup range +12 px", choose_upgrade.bind(Upgrade.MAGNET))
        add_screen_button("Shield   |   Block one hit", choose_upgrade.bind(Upgrade.SHIELD))
        add_screen_button("Main Menu", show_menu)
        return
    add_screen_button("Restart [R]", restart)
    add_screen_button("Main Menu", show_menu)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, SIZE), Color("101827"))
    for x in range(0, 961, 40):
        draw_line(Vector2(x, 0), Vector2(x, 540), Color("1c2a3a"), 1)
    for y in range(0, 541, 40):
        draw_line(Vector2(0, y), Vector2(960, y), Color("1c2a3a"), 1)
    draw_rect(Rect2(0, 0, SIZE.x, 48), Color("20344b"))
    for orb in orbs:
        draw_circle(orb, ORB_RADIUS + 4, Color("9b7724"))
        draw_circle(orb, ORB_RADIUS, Color("ffd166"))
    for drone in drones:
        draw_circle(drone["position"], DRONE_RADIUS, Color("ef476f"))
        draw_circle(drone["position"], 6, Color("7e2038"))
    var player_color := Color("06d6a0") if hit_cooldown <= 0.0 else Color("a5f3dd")
    draw_circle(player_pos, PLAYER_RADIUS, player_color)
    draw_arc(player_pos, PLAYER_RADIUS + 4, 0, TAU, 30, Color("80ffda"), 2)

    if magnet_upgrades > 0:
        draw_arc(player_pos, PLAYER_RADIUS + ORB_RADIUS + magnet_upgrades * MAGNET_BONUS,
            0, TAU, 48, Color("#ffd16670"), 1.5)
    if shield_charges > 0:
        draw_arc(player_pos, PLAYER_RADIUS + 9, 0, TAU, 32, Color("#7dccff"), 2)
    if dash_time > 0.0:
        draw_line(player_pos - dash_direction * 35.0, player_pos, Color("#80ffda"), 5)
