extends Control
## Independent, finger-friendly camera orbit pad. Touches are consumed here,
## never forwarded to the GLB picking/vertex-editing viewport.
signal direction_changed(direction: Vector2)

const RING_COLOR := Color(0.38, 0.75, 0.88, 0.48)
const PAD_COLOR := Color(0.08, 0.15, 0.23, 0.72)
const THUMB_COLOR := Color(0.29, 0.91, 0.80, 0.88)
const ICON_COLOR := Color(0.88, 0.97, 1.0, 0.82)

var direction: Vector2 = Vector2.ZERO
var active_touch: int = -1
var mouse_active: bool = false
var pad_radius: float = 60.0
var focus_label: String = "ORBIT"

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(162, 162)
    focus_mode = Control.FOCUS_NONE
    set_process(false)
    resized.connect(queue_redraw)
    queue_redraw()

func _draw() -> void:
    var center: Vector2 = size * 0.5
    var r: float = maxf(26.0, minf(size.x, size.y) * 0.36)
    pad_radius = r
    draw_circle(center, r + 15.0, Color(0.015, 0.040, 0.065, 0.34))
    draw_circle(center, r + 8.0, PAD_COLOR)
    draw_arc(center, r + 8.0, 0.0, TAU, 64, RING_COLOR, 3.0, true)
    draw_line(center + Vector2(-r * 0.90, 0), center + Vector2(r * 0.90, 0), Color(0.39, 0.64, 0.76, 0.33), 2.0, true)
    draw_line(center + Vector2(0, -r * 0.90), center + Vector2(0, r * 0.90), Color(0.39, 0.64, 0.76, 0.33), 2.0, true)
    draw_arc(center, r * 0.55, 0.0, TAU, 48, Color(0.41, 0.83, 0.91, 0.20), 2.0, true)
    var grip: Vector2 = center + direction * r
    draw_circle(grip, 26.0, Color(0.01, 0.06, 0.09, 0.68))
    draw_circle(grip, 22.0, THUMB_COLOR)
    draw_arc(grip, 22.0, 0.0, TAU, 48, Color(0.88, 1.0, 0.98, 0.72), 2.0, true)
    var font: Font = ThemeDB.fallback_font
    if font != null:
        draw_string(font, center + Vector2(-25, -r - 20), focus_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ICON_COLOR)
        draw_string(font, center + Vector2(-r - 26, 6), "◀", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ICON_COLOR)
        draw_string(font, center + Vector2(r + 10, 6), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ICON_COLOR)

func _gui_input(event: InputEvent) -> void:
    # Android's mouse-from-touch emulation can send both streams. Handle
    # native ScreenTouch/Drag only on Android to avoid double movement.
    var android: bool = OS.get_name() == "Android"
    if event is InputEventScreenTouch:
        if event.pressed:
            if active_touch == -1 and _within_pad(event.position):
                active_touch = event.index
                _set_direction(event.position)
                accept_event()
        elif event.index == active_touch:
            release()
            accept_event()
    elif event is InputEventScreenDrag and event.index == active_touch:
        _set_direction(event.position)
        accept_event()
    elif not android and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and _within_pad(event.position):
            mouse_active = true
            _set_direction(event.position)
            accept_event()
        elif not event.pressed and mouse_active:
            release()
            accept_event()
    elif not android and event is InputEventMouseMotion and mouse_active:
        _set_direction(event.position)
        accept_event()

func _within_pad(point: Vector2) -> bool:
    return point.distance_to(size * 0.5) <= maxf(30.0, minf(size.x, size.y) * 0.51)

func _set_direction(local_position: Vector2) -> void:
    var center: Vector2 = size * 0.5
    var raw: Vector2 = (local_position - center) / maxf(26.0, minf(size.x, size.y) * 0.36)
    if raw.length() < 0.12:
        raw = Vector2.ZERO
    direction = raw.limit_length(1.0)
    direction_changed.emit(direction)
    queue_redraw()

func release() -> void:
    active_touch = -1
    mouse_active = false
    direction = Vector2.ZERO
    direction_changed.emit(direction)
    queue_redraw()
