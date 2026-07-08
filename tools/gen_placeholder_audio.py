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


def rotor_loop(length=2.0, blade_hz=10.8, base_hz=32.0):
    """Loopable Huey whump: pulse-train amplitude mod over low drone + noise."""
    n = int(SR * length)
    out = []
    for i in range(n):
        t = i / SR
        pulse = 0.55 + 0.45 * max(0.0, math.sin(2 * math.pi * blade_hz * t)) ** 3
        drone = math.sin(2 * math.pi * base_hz * t) * 0.5 + math.sin(2 * math.pi * base_hz * 2.02 * t) * 0.25
        wind = (random.random() * 2 - 1) * 0.25
        out.append((drone + wind) * pulse)
    out = lowpass(out, 0.25)
    peak = max(abs(s) for s in out)
    return [s / peak * 0.85 for s in out]


write_wav("rotor_loop.wav", rotor_loop())
write_wav("wind_loop.wav", lowpass([(random.random() * 2 - 1) * 0.6 for _ in range(int(SR * 2.0))], 0.15))


def jungle_loop(length=12.0):
    """Jungle bed: soft broadband hiss + insect shimmer + sparse bird chirps."""
    n = int(SR * length)
    out = lowpass([(random.random() * 2 - 1) * 0.28 for _ in range(n)], 0.08)
    # Insect shimmer: high sine warble.
    for i in range(n):
        t = i / SR
        out[i] += math.sin(2 * math.pi * 5200 * t + 3 * math.sin(2 * math.pi * 7 * t)) * 0.045
    # Sparse chirps.
    for _ in range(10):
        start = random.randint(0, n - SR // 3)
        f = random.uniform(1400, 3200)
        for j in range(SR // 6):
            t = j / SR
            out[start + j] += math.sin(2 * math.pi * (f + 600 * math.sin(12 * t)) * t) * 0.12 * env(t, 0.01, 0.05)
    peak = max(abs(s) for s in out)
    return [s / peak * 0.6 for s in out]


def distant_war_loop(length=16.0):
    """Far-off artillery rumbles, irregular."""
    n = int(SR * length)
    out = [0.0] * n
    for _ in range(6):
        start = random.randint(0, n - SR)
        f = random.uniform(38, 60)
        for j in range(SR):
            t = j / SR
            out[start + j] += math.sin(2 * math.pi * f * t) * 0.5 * env(t, 0.03, 0.35)
    out = lowpass(out, 0.1)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * 0.7 for s in out]


def radio_crackle(length=6.0):
    n = int(SR * length)
    out = []
    for i in range(n):
        s = (random.random() * 2 - 1) * 0.12
        if random.random() < 0.0015:
            s += (random.random() * 2 - 1) * 0.6
        out.append(s)
    return lowpass(out, 0.4)


def combat_sting():
    """Two low tom hits - contact!"""
    n = int(SR * 0.9)
    out = [0.0] * n
    for k, start_s in enumerate([0.0, 0.28]):
        start = int(SR * start_s)
        for j in range(int(SR * 0.4)):
            t = j / SR
            out[start + j] += math.sin(2 * math.pi * (95 - k * 15) * t) * env(t, 0.005, 0.09)
    peak = max(abs(s) for s in out)
    return [s / peak * 0.9 for s in out]


def footstep(tone, crunch, length=0.11):
    n = int(SR * length)
    out = []
    for i in range(n):
        t = i / SR
        s = (random.random() * 2 - 1) * crunch * env(t, 0.002, 0.02)
        s += math.sin(2 * math.pi * tone * t) * 0.35 * env(t, 0.002, 0.03)
        out.append(s)
    return lowpass(out, 0.45)


write_wav("step_dirt.wav", footstep(110, 0.5))
write_wav("step_grass.wav", lowpass(footstep(90, 0.7), 0.25))
write_wav("step_water.wav", footstep(220, 0.9, 0.16))

write_wav("jungle_loop.wav", jungle_loop())
write_wav("distant_war_loop.wav", distant_war_loop())
write_wav("radio_crackle.wav", radio_crackle())
write_wav("combat_sting.wav", combat_sting())
