extends Node

const RATE := 22050

var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var cues: Dictionary
var muted := false
var settings := ConfigFile.new()

func _ready() -> void:
    music = AudioStreamPlayer.new()
    effects = AudioStreamPlayer.new()
    add_child(music)
    add_child(effects)
    music.volume_db = -12.0
    effects.volume_db = -8.0
    cues = {
        "collect": synth([76, 83], 0.075),
        "hit": synth([45, 38], 0.10),
        "shield": synth([69, 57, 76], 0.06),
        "clear": synth([60, 64, 67, 72], 0.14),
        "win": synth([60, 64, 67, 72, 76, 84], 0.19),
        "loss": synth([60, 55, 51, 48], 0.22),
    }
    music.stream = synth([
        60, 67, 72, 76, 72, 67, 64, 67,
        57, 64, 69, 72, 76, 72, 69, 64,
        53, 60, 65, 69, 72, 69, 65, 60,
        55, 62, 67, 71, 74, 71, 67, 62,
    ], 0.24, true)
    if settings.load("user://orbit_settings.cfg") == OK:
        muted = settings.get_value("audio", "muted", false)
    music.stream_paused = muted

func toggle() -> void:
    muted = not muted
    music.stream_paused = muted
    if muted:
        effects.stop()
    settings.set_value("audio", "muted", muted)
    settings.save("user://orbit_settings.cfg")

func start_music() -> void:
    if not music.playing:
        music.play()
        music.stream_paused = muted

func play_cue(cue: String) -> void:
    if not muted:
        effects.stream = cues[cue]
        effects.play()

# Render original synthesized notes to mono, signed 16-bit PCM.
func synth(notes: Array, duration: float, loop := false) -> AudioStreamWAV:
    var frames := int(RATE * duration)
    var data := PackedByteArray()
    data.resize(frames * notes.size() * 2)
    for note_index in range(notes.size()):
        var hz := 440.0 * pow(2.0, (float(notes[note_index]) - 69.0) / 12.0)
        for frame in range(frames):
            var t := float(frame) / RATE
            var envelope := minf(1.0, t / 0.008) * maxf(0.0, 1.0 - t / duration)
            var tone := sin(TAU * hz * t) + 0.24 * sin(TAU * hz * 2.0 * t)
            if loop:
                var bass := 440.0 * pow(2.0, (float(notes[note_index - note_index % 8]) - 93.0) / 12.0)
                tone = 0.62 * tone + 0.38 * sin(TAU * bass * t)
            data.encode_s16((note_index * frames + frame) * 2, int(15000 * tone * envelope))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    stream.data = data
    if loop:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_end = frames * notes.size()
    return stream

