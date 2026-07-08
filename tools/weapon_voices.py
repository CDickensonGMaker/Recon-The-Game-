"""weapon_voices.py - Physical/acoustic parameters per weapon.

This is the tuning table. Everything downstream is derived from it. If a gun
sounds wrong, fix it HERE, not in the synth.

Sourcing note: `powder_g`, `bore_mm`, `barrel_mm`, `mv_ms` are real published
figures. `f_low`, `brightness`, `drive` are ACOUSTIC JUDGEMENT -- they are
derived from the physical numbers by `derive()` below, then hand-nudged where
a weapon has a famous signature the formula misses (the AK's flat crack, the
M16's higher tinny pop, the RPD's slower heavier cadence).

Layer glossary (see audio_dsp.py):
  f_low       Hz   body/thump resonance. Big charge + big bore -> lower.
  brightness  Hz   muzzle-blast lowpass cutoff. Short barrel -> brighter/harsher
                   (more unburnt powder detonating outside the muzzle).
  crack       0-1  supersonic N-wave amount. Subsonic rounds -> 0.0.
  drive       >0   saturation. Bigger charge overdrives harder.
  blast_tau   s    Friedlander time constant. Longer = fatter report.
  mech        dict mechanical action layer: freqs, delay, level.
"""

from __future__ import annotations

SUBSONIC = 0.0


def derive(bore_mm: float, powder_g: float, barrel_mm: float) -> dict:
    """Physically-motivated defaults. Hand-overrides win over these.

    blast_tau is the POSITIVE-PHASE DURATION of the Friedlander overpressure
    wave, in seconds. Real small arms measure 0.2-0.5 ms at the shooter's ear;
    artillery runs into milliseconds. Getting this wrong by 10x turns every gun
    into a kick drum -- a Friedlander wave with tau=4 ms has its spectral
    centroid at 12 Hz.
    """
    f_low = 150.0 * (1.6 / powder_g) ** 0.30 * (7.62 / bore_mm) ** 0.35
    # Short barrels dump unburnt powder into free air: louder, harsher, brighter.
    brightness = 7000.0 * (508.0 / barrel_mm) ** 0.30 * (powder_g / 1.6) ** 0.18
    brightness = min(max(brightness, 5200.0), 13000.0)
    # Woody mid resonance of the bore + gas column.
    bark_hz = 900.0 * (7.62 / bore_mm) ** 0.40 * (1.6 / powder_g) ** 0.15
    drive = 1.15 + 0.30 * (powder_g ** 0.5)
    blast_tau = max(0.00028, 0.00030 * (powder_g ** 0.40) * (bore_mm / 7.62) ** 0.25)
    return {
        "f_low": round(f_low, 1),
        "brightness": round(brightness, 1),
        "bark_hz": round(bark_hz, 1),
        "drive": round(drive, 2),
        "blast_tau": round(blast_tau, 6),
    }


def _mech(freqs, delay, level, ring=0.004, n=2):
    return {"freqs": freqs, "delay": delay, "level": level, "ring": ring, "n": n}


# --------------------------------------------------------------------------
# The table. `over` = hand overrides applied after derive().
# --------------------------------------------------------------------------

WEAPONS: dict[str, dict] = {

    # ---- US ----------------------------------------------------------------
    "m16a1": dict(
        name="M16A1", bore_mm=5.56, powder_g=1.70, barrel_mm=508, mv_ms=990,
        crack=0.95,
        # Veteran shorthand: the M16 is a higher, flatter, *tinnier* report than
        # the AK -- less bass, a metallic aftertone from the alloy receiver and
        # the buffer spring twanging in the stock.
        over=dict(f_low=190.0, brightness=11000.0, bark_hz=1550.0, drive=1.3, blast_tau=0.00032),
        mech=_mech([2400, 3900, 5200], 0.011, 0.16, ring=0.010, n=3),  # buffer spring twang
        tail=("jungle", 0.55),
    ),
    "car15": dict(
        name="CAR-15 / XM177", bore_mm=5.56, powder_g=1.70, barrel_mm=254, mv_ms=838,
        crack=0.90,
        # 10" barrel + moderator: notoriously LOUD and concussive, much more
        # blast, less crack, deeper than the M16 despite the same cartridge.
        over=dict(f_low=165.0, brightness=11500.0, bark_hz=1350.0, drive=1.6, blast_tau=0.0004),
        mech=_mech([2200, 3600], 0.010, 0.15, ring=0.008, n=2),
        tail=("jungle", 0.62),
    ),
    "m60": dict(
        name="M60", bore_mm=7.62, powder_g=3.20, barrel_mm=560, mv_ms=853,
        crack=0.92,
        # "The Pig." Deep, slow, authoritative. Belt links + heavy op-rod.
        over=dict(f_low=98.0, brightness=7600.0, bark_hz=780.0, drive=1.7, blast_tau=0.00052),
        mech=_mech([900, 1700, 2900], 0.008, 0.26, ring=0.014, n=4),  # link rattle
        tail=("jungle", 0.75),
    ),
    "m1911": dict(
        name="M1911A1", bore_mm=11.43, powder_g=0.35, barrel_mm=127, mv_ms=253,
        crack=SUBSONIC,  # .45 ACP is subsonic. No crack. Only the report.
        over=dict(f_low=205.0, brightness=8200.0, bark_hz=1250.0, drive=1.35, blast_tau=0.00034),
        mech=_mech([1500, 2600], 0.018, 0.30, ring=0.009, n=2),  # slide slam
        tail=("jungle", 0.40),
    ),
    "thompson": dict(
        name="Thompson M1A1", bore_mm=11.43, powder_g=0.35, barrel_mm=267, mv_ms=285,
        crack=SUBSONIC,
        # Heavy blowback bolt: the CLATTER is as loud as the report.
        over=dict(f_low=195.0, brightness=7400.0, bark_hz=1100.0, drive=1.35, blast_tau=0.00034),
        mech=_mech([1100, 1900, 3100], 0.009, 0.34, ring=0.011, n=3),
        tail=("jungle", 0.45),
    ),
    "m79": dict(
        name="M79 Blooper", bore_mm=40.0, powder_g=0.30, barrel_mm=356, mv_ms=76,
        crack=SUBSONIC,
        # The famous hollow "THOONK" / "bloop". Low-pressure launch, huge bore.
        over=dict(f_low=240.0, brightness=2600.0, bark_hz=420.0, drive=1.1, blast_tau=0.0028),
        mech=_mech([620, 980], 0.030, 0.22, ring=0.018, n=2),
        tail=("jungle", 0.30),
    ),
    "m72_law": dict(
        name="M72 LAW", bore_mm=66.0, powder_g=0.45, barrel_mm=630, mv_ms=145,
        crack=SUBSONIC,
        # Recoilless: the BACKBLAST is the sound. A hissing roar, not a bang.
        over=dict(f_low=115.0, brightness=5600.0, bark_hz=600.0, drive=1.6, blast_tau=0.0055),
        mech=_mech([700, 1400], 0.002, 0.10, ring=0.030, n=1),
        tail=("open", 0.85), rocket_hiss=0.55,
    ),

    # ---- Communist bloc ----------------------------------------------------
    "ak47": dict(
        name="AK-47 / Type 56", bore_mm=7.62, powder_g=1.60, barrel_mm=415, mv_ms=715,
        crack=0.88,
        # The signature: a flat, woody CRACK with a heavier bass thump under it
        # than the M16, and a loose, rattling action. This is the sound US troops
        # learned to pick out of a firefight.
        over=dict(f_low=128.0, brightness=7400.0, bark_hz=980.0, drive=1.6, blast_tau=0.00044),
        mech=_mech([1300, 2100, 3400], 0.013, 0.28, ring=0.012, n=3),  # loose action
        tail=("jungle", 0.68),
    ),
    "sks": dict(
        name="SKS", bore_mm=7.62, powder_g=1.60, barrel_mm=520, mv_ms=735,
        crack=0.88,
        # Same cartridge as the AK, longer barrel: less muzzle blast, more crack,
        # tighter action. Reads as "sharper and cleaner than an AK."
        over=dict(f_low=132.0, brightness=8800.0, bark_hz=1150.0, drive=1.45, blast_tau=0.00038),
        mech=_mech([1600, 2700], 0.012, 0.20, ring=0.008, n=2),
        tail=("jungle", 0.66),
    ),
    "rpd": dict(
        name="RPD", bore_mm=7.62, powder_g=1.60, barrel_mm=520, mv_ms=735,
        crack=0.88,
        over=dict(f_low=122.0, brightness=8000.0, bark_hz=950.0, drive=1.6, blast_tau=0.00046),
        mech=_mech([800, 1500, 2600], 0.007, 0.30, ring=0.015, n=4),  # belt + drum
        tail=("jungle", 0.72),
    ),
    "ppsh41": dict(
        name="PPSh-41", bore_mm=7.62, powder_g=0.50, barrel_mm=269, mv_ms=488,
        crack=0.45,  # 7.62x25 IS supersonic -- a small, thin crack
        # The "burp gun": 900+ rpm, high, buzzy, almost a single tearing noise.
        over=dict(f_low=235.0, brightness=10500.0, bark_hz=1700.0, drive=1.3, blast_tau=0.0003),
        mech=_mech([1800, 3000], 0.006, 0.30, ring=0.007, n=2),
        tail=("jungle", 0.42),
    ),
    "mosin": dict(
        name="Mosin-Nagant 91/30", bore_mm=7.62, powder_g=3.25, barrel_mm=730, mv_ms=865,
        crack=0.98,
        # Long barrel, big charge: enormous, echoing report. Slow to speak.
        over=dict(f_low=94.0, brightness=8000.0, bark_hz=760.0, drive=1.75, blast_tau=0.00055),
        mech=_mech([700, 1300, 2300], 0.055, 0.30, ring=0.030, n=4),  # bolt throw
        tail=("open", 0.95),
    ),
    "rpg2": dict(
        name="RPG-2", bore_mm=40.0, powder_g=0.35, barrel_mm=650, mv_ms=84,
        crack=SUBSONIC,
        over=dict(f_low=125.0, brightness=5400.0, bark_hz=560.0, drive=1.5, blast_tau=0.0045),
        mech=_mech([600, 1100], 0.003, 0.12, ring=0.025, n=1),
        tail=("open", 0.80), rocket_hiss=0.50,
    ),
    "rpg7": dict(
        name="RPG-7", bore_mm=40.0, powder_g=0.60, barrel_mm=950, mv_ms=115,
        crack=SUBSONIC,
        # Booster ignites downrange: launch THUMP, then the sustainer WHOOSH.
        over=dict(f_low=105.0, brightness=5800.0, bark_hz=520.0, drive=1.6, blast_tau=0.0052),
        mech=_mech([580, 1050], 0.003, 0.12, ring=0.028, n=1),
        tail=("open", 0.88), rocket_hiss=0.70,
    ),

    # ---- WW-era, black-market (Caleb's call: they were all in-theatre) ------
    "mp40": dict(
        name="MP40", bore_mm=9.0, powder_g=0.36, barrel_mm=251, mv_ms=380,
        crack=SUBSONIC,  # 9x19 ball is subsonic-to-transonic from a 10" barrel
        over=dict(f_low=215.0, brightness=8000.0, bark_hz=1300.0, drive=1.3, blast_tau=0.00032),
        mech=_mech([1400, 2400], 0.011, 0.32, ring=0.010, n=3),  # slow heavy bolt
        tail=("jungle", 0.44),
    ),
    "kar98k": dict(
        name="Kar 98k", bore_mm=7.92, powder_g=3.05, barrel_mm=600, mv_ms=760,
        crack=0.97,
        over=dict(f_low=100.0, brightness=8200.0, bark_hz=800.0, drive=1.7, blast_tau=0.00054),
        mech=_mech([850, 1500, 2500], 0.050, 0.28, ring=0.026, n=4),  # Mauser bolt
        tail=("open", 0.92),
    ),
}


# --------------------------------------------------------------------------
# Explosions / ordnance. Distinct model: no bore, no crack -- just blast.
# --------------------------------------------------------------------------

EXPLOSIONS: dict[str, dict] = {
    # M26 frag: ~165g Comp B. Sharp, high crack close in; the debris/frag
    # hiss is the tell. Not a movie fireball.
    "explosion_grenade": dict(f_low=62.0, blast_tau=0.0016, brightness=7200.0, bark_hz=340.0,
                              drive=2.0, tail=("jungle", 1.4), debris=0.55, rumble=0.7),
    # RPG / LAW HEAT warhead on a hard target: sharper, more metallic, less bass.
    "explosion_rocket": dict(f_low=78.0, blast_tau=0.0011, brightness=8400.0, bark_hz=430.0,
                             drive=2.1, tail=("open", 1.6), debris=0.40, rumble=0.6),
    # 40mm M79 HE: small charge, snappy, quick tail.
    "explosion_40mm": dict(f_low=95.0, blast_tau=0.0008, brightness=7800.0, bark_hz=520.0,
                           drive=1.8, tail=("jungle", 0.9), debris=0.35, rumble=0.4),
    # Artillery / airstrike / satchel: the ground moves.
    "explosion_heavy": dict(f_low=38.0, blast_tau=0.0060, brightness=5200.0, bark_hz=190.0,
                            drive=2.3, tail=("open", 2.6), debris=0.75, rumble=1.0),
}


# Environment IR presets: (seconds, decay, damping_hz, predelay, density)
ENVIRONMENTS: dict[str, tuple] = {
    # Jungle: fast, dense, dark. Foliage is a broadband absorber; there is no
    # long tail, just a thick smear that dies quickly.
    "jungle": (0.90, 0.16, 2600.0, 0.006, 1.0),
    # Open AO / paddy / hillside: longer, brighter, sparser -> discrete slapback.
    "open":   (2.20, 0.52, 5200.0, 0.022, 0.35),
}


def params(weapon_id: str) -> dict:
    w = dict(WEAPONS[weapon_id])
    p = derive(w["bore_mm"], w["powder_g"], w["barrel_mm"])
    p.update(w.pop("over", {}))
    w.update(p)
    return w
