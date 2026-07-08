"""Generate punchy placeholder combat WAVs (stdlib only). RTCW-era crack+thump.
Run: python tools/gen_placeholder_audio.py  (writes assets/audio/sfx/)"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def write_wav(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples)
        w.writeframes(frames)
    print("wrote", name, len(samples) / SR, "s")


def env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def lowpass(samples, alpha):
    out, acc = [], 0.0
    for s in samples:
        acc += alpha * (s - acc)
        out.append(acc)
    return out


def gunshot(body_hz, crack_amt, length=0.22, decay=0.045):
    n = int(SR * length)
    out = []
    for i in range(n):
        t = i / SR
        noise = (random.random() * 2 - 1) * crack_amt * env(t, 0.001, decay)
        thump = math.sin(2 * math.pi * body_hz * t) * 0.9 * env(t, 0.002, 0.06)
        sub = math.sin(2 * math.pi * (body_hz * 0.5) * t) * 0.5 * env(t, 0.002, 0.09)
        out.append(noise + thump + sub)
    peak = max(abs(s) for s in out)
    return [s / peak * 0.95 for s in out]


def impact(length=0.08, tone=180.0):
    n = int(SR * length)
    out = []
    for i in range(n):
        t = i / SR
        noise = (random.random() * 2 - 1) * 0.8 * env(t, 0.001, 0.02)
        thud = math.sin(2 * math.pi * tone * t) * 0.6 * env(t, 0.001, 0.03)
        out.append(noise + thud)
    return lowpass(out, 0.35)


def click():
    n = int(SR * 0.05)
    return [((random.random() * 2 - 1) * 0.5 + math.sin(2 * math.pi * 2200 * i / SR) * 0.4) * env(i / SR, 0.001, 0.008) for i in range(n)]


write_wav("shot_rifle.wav", gunshot(115.0, 1.0))
write_wav("shot_smg.wav", gunshot(140.0, 0.85, 0.18, 0.03))
write_wav("shot_pistol.wav", gunshot(160.0, 0.8, 0.16, 0.028))
write_wav("shot_distant.wav", lowpass(gunshot(90.0, 0.55, 0.4, 0.09), 0.12))
write_wav("impact_dirt.wav", impact(0.08, 150.0))
write_wav("impact_hard.wav", impact(0.06, 320.0))
write_wav("dry_click.wav", click())
write_wav("explosion.wav", lowpass(gunshot(55.0, 0.9, 0.9, 0.22), 0.2))
