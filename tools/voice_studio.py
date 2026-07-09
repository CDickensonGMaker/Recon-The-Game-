"""voice_studio.py - free local voice-line generator for RECONgame.

Pipeline: Piper (free neural TTS) -> your audio_dsp.py (radio/field processing) -> .wav.
No cloud, no cost. 6 US male voices installed under tools/tts/piper/.

USAGE
  Type your own line (quick):
    python tools/voice_studio.py --say "Fire mission, over" --voice ryan --profile radio --play
  Interactive (type line after line):
    python tools/voice_studio.py --interactive --voice ryan --profile radio
  Build the whole manifest in ALL voices (game assets):
    python tools/voice_studio.py --all
  Voice-compare reel (same lines, every voice, self-labeled):
    python tools/voice_studio.py --compare
  List voices:
    python tools/voice_studio.py --voices

profiles: radio (band-limited comms + squelch) | field (shouted in the open) | clean
"""
from __future__ import annotations
import argparse, os, subprocess, sys, tempfile, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_dsp as D  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PIPER = os.path.join(HERE, "tts", "piper", "piper.exe")
VOICE_DIR = os.path.join(HERE, "tts", "piper")
OUT_ROOT = os.path.join(os.path.dirname(HERE), "assets", "audio", "vo")

# ---------------------------------------------------------------- lines manifest
# category -> { line_id: text }.  Existing in-code barks + 20+ fillers.
LINES = {
    "radio": {  # RTO / call-for-fire - band-limited comms treatment
        "fire_mission":   "All stations, this is Recon Two-Four. Fire mission, over.",
        "shot_splash":    "Shot, over. Splash, over.",
        "snake_eye":      "Fast mover inbound, snake eye. Get your heads down.",
        "napalm_run":     "Napalm run inbound. Danger close. Get back.",
        "cbu_cluster":    "Fast mover inbound, cluster run. Everybody down.",
        "arty_barrage":   "Battery fire mission. Shot out.",
        "mortar_mission": "Fire mission. Spot round out.",
        "spooky":         "Spooky on station. Thirty seconds of rain.",
        "danger_close":   "Danger close. Confirm your position, over.",
        "dustoff":        "Requesting dust-off. We have wounded, over.",
        "winchester":     "Be advised, we are Winchester. Black on ammo, over.",
        "say_again":      "Say again your last, over.",
        "roger_out":      "Roger that. Out.",
        "no_commo":       "Negative. We've lost commo. The radio's down.",
        "on_the_horn":    "Get on the horn. Send your fire mission.",
    },
    "squad": {  # squad barks - shouted in the field
        "contact_front":  "Contact front! Get down!",
        "contact":        "Contact! Contact!",
        "movement_ahead": "Hold up! Movement ahead!",
        "thumper_out":    "Thumper out!",
        "man_down":       "Man down! I need a medic!",
        "doc_moving":     "Doc's moving to you! Hang on!",
        "on_your_feet":   "You're good! On your feet!",
        "weapons_free":   "Weapons free!",
        "weapons_tight":  "Hold your fire!",
        "reloading_cov":  "Reloading! Cover me!",
        "frag_out":       "Frag out!",
        "moving":         "Moving! Moving!",
        "enemy_left":     "Enemy left!",
        "enemy_right":    "Enemy right!",
        "grenade":        "Grenade! Take cover!",
        "taking_fire":    "Taking fire! Taking fire!",
        "fall_back":      "Fall back! Fall back!",
        "sniper":         "Sniper! Get down!",
        "clear":          "Clear!",
        "ammo_low":       "I'm low on ammo!",
        "push_up":        "Push up! Push up!",
        "treeline":       "Charlie in the treeline!",
        "on_me":          "On me! Form up!",
        "fire_in_hole":   "Fire in the hole!",
        "reloading":      "Reloading!",
    },
    "enemy": {  # VC/NVA Vietnamese callouts - FULL SENTENCES (short exclamations don't
                # read as speech in the low-quality VN model). Use a vi_ voice.
        "spotted_us": "Có lính Mỹ ở phía trước, anh em coi chừng!",   # Americans ahead, watch out
        "open_fire":  "Bắn vào bọn chúng đi, bắn ngay!",               # Fire at them now
        "grenade":    "Coi chừng, bọn chúng ném lựu đạn!",             # Watch out, they're throwing grenades
        "flanking":   "Chúng nó đang bọc sườn ta, cẩn thận!",          # They're flanking us, careful
        "retreat":    "Rút lui mau lên, nhanh chân anh em!",           # Retreat quickly, hurry
        "reload":     "Chờ một chút, tôi hết đạn rồi!",                # Wait, I'm out of ammo
        "advance":    "Tiến lên, đừng để chúng nó chạy thoát!",        # Advance, don't let them escape
        "man_down":   "Có người bị thương, gọi cứu thương mau!",       # Man wounded, call a medic
        "surrender":  "Đừng bắn, tôi xin đầu hàng, tôi đầu hàng!",     # Don't shoot, I surrender
        "taunt":      "Bọn Mỹ, chúng mày sẽ chết ở đây hết!",          # You Americans will all die here
    },
}
CAT_PROFILE = {"radio": "radio", "squad": "field", "enemy": "field"}
CAT_LANG = {"radio": "en", "squad": "en", "enemy": "vi"}

# speaking rate per language (Piper --length_scale: <1 faster, >1 slower). The US
# voices ran a touch slow and the Vietnamese a touch fast at the 1.0 default.
LANG_LENGTH = {"en": 0.86, "vi": 1.28}

def voice_lang(voice: str) -> str:
    return "vi" if voice.startswith("vi") else "en"

# ---------------------------------------------------------------- piper + dsp
# Voices the user removed from the lineup - never regenerate (models kept on disk).
SKIP_VOICES = {"hfc_female", "kristin"}

# Role assignments from voice-over test feedback (2026-07-09):
VOICE_ROLES = {
    "joe":    "radio operator (comms only)",
    "john":   "squad barks / main NPC voice",
    "norman": "medic",
    "ryan":   "standard / rookie grunt",
    # bryce, hfc_male = 'too happy', not assigned a serious role
}

def voices() -> list[str]:
    if not os.path.isdir(VOICE_DIR):
        return []
    return sorted(f[:-5] for f in os.listdir(VOICE_DIR)
                  if f.endswith(".onnx") and f[:-5] not in SKIP_VOICES)

def _resample(x: np.ndarray, sr_in: int, sr_out: int = D.SR) -> np.ndarray:
    if sr_in == sr_out:
        return x
    n = int(len(x) * sr_out / sr_in)
    return np.interp(np.linspace(0, len(x), n, endpoint=False), np.arange(len(x)), x)

def piper_raw(text: str, voice: str, length_scale: float | None = None) -> np.ndarray:
    """Run Piper -> mono float array at D.SR. length_scale <1 faster, >1 slower;
    None uses the per-language default (LANG_LENGTH)."""
    model = os.path.join(VOICE_DIR, voice + ".onnx")
    if length_scale is None:
        length_scale = LANG_LENGTH.get(voice_lang(voice), 1.0)
    fd, tmp = tempfile.mkstemp(suffix=".wav"); os.close(fd)
    try:
        subprocess.run([PIPER, "-m", model, "--length_scale", str(length_scale), "-f", tmp],
                       input=text.encode("utf-8"), capture_output=True, check=True)
        with wave.open(tmp) as w:
            sr = w.getframerate()
            x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768.0
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
    return _resample(x, sr)

_rng = np.random.default_rng(11)
def _squelch(dur: float = 0.05, lvl: float = 0.6) -> np.ndarray:
    n = int(dur * D.SR)
    return D.expdecay(n, 0.012) * D.bandpass(D.noise(n, _rng) * lvl, 1600, q=0.8)

def proc_radio(x: np.ndarray) -> np.ndarray:
    y = D.highpass(x, 400, passes=2)
    y = D.lowpass(y, 2600, passes=2)
    y = D.saturate(y, 3.4)
    y = y + D.noise(len(y), _rng) * 0.02
    return np.concatenate([_squelch(), D.normalize(y, 0.9), _squelch(0.04)])

def proc_field(x: np.ndarray) -> np.ndarray:
    # Shouted + aggressive but CLEAR: the old hard clip (0.82) + drive 3.4 mangled
    # consonant-heavy words ("contact" came out garbled). Lighter drive + a gentle
    # edge keeps the yell/strain without tearing the diction apart.
    y = D.highpass(x, 180)                     # thin the lows -> forward, urgent
    y = y + D.bandpass(y, 2500, q=0.9) * 0.5   # presence/bite (yelling formants), lighter
    y = D.saturate(y, 2.4)                      # aggression, not destruction
    y = np.clip(y, -0.93, 0.93)                # gentle edge only
    return D.normalize(y, 0.97)

def proc_clean(x: np.ndarray) -> np.ndarray:
    return D.normalize(x, 0.95)

PROFILES = {"radio": proc_radio, "field": proc_field, "clean": proc_clean}

def generate(text: str, voice: str, profile: str, length_scale: float | None = None) -> np.ndarray:
    return PROFILES[profile](piper_raw(text, voice, length_scale))

# ---------------------------------------------------------------- commands
def cmd_say(args):
    y = generate(args.say, args.voice, args.profile, args.length_scale)
    out = args.out or os.path.join(tempfile.gettempdir(), "vo_say.wav")
    D.write_wav(out, y)
    print(out)
    if args.play:
        _play(out)

def cmd_interactive(args):
    print("Type a line, ENTER to hear it. 'voice X' to switch, 'profile X' to switch, blank to quit.")
    print("voices:", ", ".join(voices()))
    v, prof = args.voice, args.profile
    while True:
        try:
            line = input(f"[{v}/{prof}] > ").strip()
        except EOFError:
            break
        if not line:
            break
        if line.startswith("voice "):
            v = line.split(None, 1)[1].strip(); continue
        if line.startswith("profile "):
            prof = line.split(None, 1)[1].strip(); continue
        out = os.path.join(tempfile.gettempdir(), "vo_say.wav")
        D.write_wav(out, generate(line, v, prof))
        _play(out)

RADIO_VOICE = "joe"  # the designated radio operator - the only voice that does radio calls

def _voices_for(cat: str, vs: list[str]) -> list[str]:
    if cat == "radio":
        return [RADIO_VOICE] if RADIO_VOICE in vs else vs[:1]
    return [v for v in vs if voice_lang(v) == CAT_LANG[cat]]  # squad = all US, enemy = all VN

def cmd_all(args):
    vs = voices()
    tasks = [(cat, v, lid, text) for cat, d in LINES.items()
             for v in _voices_for(cat, vs) for lid, text in d.items()]
    print(f"generating {len(tasks)} lines (radio=Joe only, squad=all US, enemy=all VN)...")
    for i, (cat, v, lid, text) in enumerate(tasks, 1):
        vdir = os.path.join(OUT_ROOT, v)
        os.makedirs(vdir, exist_ok=True)
        D.write_wav(os.path.join(vdir, f"{cat}_{lid}.wav"), generate(text, v, CAT_PROFILE[cat]))
        if i % 20 == 0:
            print(f"  {i}/{len(tasks)}")
    print(f"done -> {OUT_ROOT}\\<voice>\\<cat>_<line>.wav")

def cmd_compare(args):
    """Same key lines in every voice, each self-labeled, into one reel."""
    picks = [("radio", "fire_mission"), ("squad", "contact_front"), ("squad", "man_down")]
    gap = np.zeros(int(0.6 * D.SR))
    biggap = np.zeros(int(1.1 * D.SR))
    reel = []
    for v in voices():
        label = proc_clean(piper_raw(f"Voice: {v}.", v))
        reel.append(label); reel.append(gap)
        for cat, lid in picks:
            reel.append(generate(LINES[cat][lid], v, CAT_PROFILE[cat])); reel.append(gap)
        reel.append(biggap)
    out = args.out or os.path.join(tempfile.gettempdir(), "COMPARE_piper_voices.wav")
    D.write_wav(out, np.concatenate(reel))
    print(out)

def _play(path: str):
    try:
        subprocess.run(["powershell", "-NoProfile", "-c",
                        f"(New-Object System.Media.SoundPlayer '{path}').PlaySync()"], check=False)
    except Exception as e:
        print("play failed:", e)

def main():
    ap = argparse.ArgumentParser(description="RECONgame free voice-line generator (Piper + audio_dsp)")
    ap.add_argument("--say", help="one line to speak")
    ap.add_argument("--voice", default="ryan", help="voice name (see --voices)")
    ap.add_argument("--profile", default="radio", choices=list(PROFILES))
    ap.add_argument("--length-scale", dest="length_scale", type=float, default=None,
                    help="speaking rate override (<1 faster, >1 slower; default per-language)")
    ap.add_argument("--out", help="output wav path")
    ap.add_argument("--play", action="store_true", help="play after generating")
    ap.add_argument("--interactive", action="store_true")
    ap.add_argument("--all", action="store_true", help="generate the whole manifest in all voices")
    ap.add_argument("--compare", action="store_true", help="voice-compare reel")
    ap.add_argument("--voices", action="store_true")
    a = ap.parse_args()
    if a.voices:
        print("\n".join(voices())); return
    if a.say:
        cmd_say(a)
    elif a.interactive:
        cmd_interactive(a)
    elif a.all:
        cmd_all(a)
    elif a.compare:
        cmd_compare(a)
    else:
        ap.print_help()

if __name__ == "__main__":
    main()
