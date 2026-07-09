"""gen_blood_fx.py - procedural HLL-style blood FX textures. No art needed, infinite variants.

Hell Let Loose blood is a PINK-MIST MOMENT, not a cartoon splat: a soft dark-red mist
puff that blooms + dissipates (~0.4s), fine droplets, and painted evidence (splats/pools).
The realism lives in particle MOTION + soft alpha; the textures are near-formless smudges -
which is exactly what fbm noise is. So we generate them, like the weapon audio.

Outputs (assets/textures/fx/blood/):
  blood_mist_sheet.png   4x2 flipbook, 8 frames 256px - the burst mist (GPUParticles anim)
  blood_droplet.png      64px fine-speck sheet for the droplet layer
  blood_splat_1..3.png   256px hard-alpha wall/floor decals (each run = new shapes)
  blood_pool_sheet.png   4x1 flipbook, growing pool for kills
  PREVIEW.png            contact sheet for eyeballing

Usage:  python tools/gen_blood_fx.py [seed]
"""
from __future__ import annotations
import os, sys
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "textures", "fx", "blood")

SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 1968
rng = np.random.default_rng(SEED)

# deep venous reds - HLL blood reads DARK, almost brown, never candy-red
C_DARK = np.array([0.28, 0.015, 0.01])
C_MID = np.array([0.45, 0.04, 0.02])


def value_noise(size: int, cells: int, r: np.random.Generator) -> np.ndarray:
    """Bilinear-interpolated value noise, vectorized."""
    g = r.random((cells + 1, cells + 1))
    xs = np.linspace(0, cells, size, endpoint=False)
    x0 = xs.astype(int)
    fx = xs - x0
    fx = fx * fx * (3 - 2 * fx)  # smoothstep
    top = g[np.ix_(x0, x0)] * np.outer(1 - fx, 1 - fx) \
        + g[np.ix_(x0, x0 + 1)] * np.outer(1 - fx, fx) \
        + g[np.ix_(x0 + 1, x0)] * np.outer(fx, 1 - fx) \
        + g[np.ix_(x0 + 1, x0 + 1)] * np.outer(fx, fx)
    return top


def fbm(size: int, r: np.random.Generator, octaves: int = 5, base_cells: int = 4) -> np.ndarray:
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += amp * value_noise(size, base_cells * (2 ** o), r)
        norm += amp
        amp *= 0.5
    return total / norm


def radial(size: int, cx: float = 0.5, cy: float = 0.5) -> np.ndarray:
    y, x = np.mgrid[0:size, 0:size] / float(size)
    return np.sqrt((x - cx) ** 2 + (y - cy) ** 2)


def save_rgba(path: str, rgb: np.ndarray, alpha: np.ndarray) -> None:
    a = np.clip(alpha, 0, 1)
    img = np.dstack([np.clip(rgb, 0, 1), a[..., None]])
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(path)


def tint(alpha: np.ndarray, tex: np.ndarray) -> np.ndarray:
    """Dark->mid red by local density: thick blood is darker."""
    t = np.clip(tex, 0, 1)[..., None]
    return C_DARK[None, None, :] * (1 - t) + C_MID[None, None, :] * t


# ---------------------------------------------------------------- mist flipbook
def gen_mist(frames: int = 8, size: int = 256) -> list[np.ndarray]:
    """A blooming, dissipating mist puff. Same noise field every frame, sampled at a
    growing radius + rising threshold = it expands, thins, and tears apart."""
    n1 = fbm(size, rng, octaves=5, base_cells=3)
    n2 = fbm(size, rng, octaves=4, base_cells=6)
    out = []
    for i in range(frames):
        t = i / float(frames - 1)                       # 0..1 life
        rad = radial(size)
        grow = 0.26 + 0.40 * t                          # puff radius blooms BIG
        fall = np.clip(1.0 - rad / grow, 0, 1) ** 0.85  # soft, generous radial body
        # churn the noise domain per frame so the cloud roils as it expands
        wisps = np.roll(np.roll(n1, i * 6, axis=0), i * 4, axis=1) * 0.65 + n2 * 0.35
        density = fall * (wisps * 0.8 + 0.3)
        thresh = 0.16 + 0.20 * t                        # dissipation tears it apart
        a = np.clip((density - thresh) * 3.8, 0, 1)
        a *= (1.0 - t) ** 1.1                           # global fade-out
        a *= 0.9                                        # mist is never fully opaque
        out.append((tint(a, wisps), a))
    return out


# ---------------------------------------------------------------- droplets
def gen_droplets(size: int = 64, count: int = 14) -> tuple[np.ndarray, np.ndarray]:
    a = np.zeros((size, size))
    yy, xx = np.mgrid[0:size, 0:size]
    for _ in range(count):
        cx, cy = rng.random(2) * size
        r = rng.uniform(0.8, 2.4)
        a = np.maximum(a, np.clip(1.0 - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r, 0, 1))
    a = np.clip(a * 1.6, 0, 1)
    return tint(a, a * 0.5), a


# ---------------------------------------------------------------- splat decals
def gen_splat(size: int = 256) -> tuple[np.ndarray, np.ndarray]:
    """Hard-alpha impact splat: dense core, ragged edge, directional drips."""
    r = np.random.default_rng(rng.integers(1 << 31))
    n = fbm(size, r, octaves=5, base_cells=5)
    rad = radial(size)
    body = n - rad * rng.uniform(1.1, 1.5)
    # drips: smear the mask downward a few times with decay
    drip = body.copy()
    for k in range(1, 22):
        shifted = np.roll(body, k * 3, axis=0) - k * 0.012
        drip = np.maximum(drip, shifted)
    mask = (drip > rng.uniform(0.06, 0.12)).astype(float)
    # hard alpha, PSX-chunky: downres then upres nearest
    small = Image.fromarray((mask * 255).astype(np.uint8)).resize((size // 4, size // 4), Image.BILINEAR)
    mask = (np.asarray(small.resize((size, size), Image.NEAREST)) / 255.0 > 0.5).astype(float)
    return tint(mask, n * 0.6), mask * 0.92


# ---------------------------------------------------------------- pool flipbook
def gen_pool(stages: int = 4, size: int = 256) -> list[np.ndarray]:
    n = fbm(size, rng, octaves=4, base_cells=4)
    rad = radial(size)
    out = []
    for i in range(stages):
        t = (i + 1) / float(stages)
        grow = 0.12 + 0.3 * t
        edge = grow * (1.0 + (n - 0.5) * 0.55)          # noisy organic edge
        mask = (rad < edge).astype(float)
        out.append((tint(mask, n * 0.35), mask * 0.96)) # pools are near-opaque + DARK
    return out


def sheet(frames: list, cols: int, size: int) -> tuple[np.ndarray, np.ndarray]:
    rows = (len(frames) + cols - 1) // cols
    rgb = np.zeros((rows * size, cols * size, 3))
    a = np.zeros((rows * size, cols * size))
    for i, (frgb, fa) in enumerate(frames):
        r, c = divmod(i, cols)
        rgb[r * size:(r + 1) * size, c * size:(c + 1) * size] = frgb
        a[r * size:(r + 1) * size, c * size:(c + 1) * size] = fa
    return rgb, a


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    mist = gen_mist()
    save_rgba(os.path.join(OUT, "blood_mist_sheet.png"), *sheet(mist, 4, 256))
    save_rgba(os.path.join(OUT, "blood_droplet.png"), *gen_droplets())
    splats = [gen_splat() for _ in range(3)]
    for i, s in enumerate(splats):
        save_rgba(os.path.join(OUT, f"blood_splat_{i + 1}.png"), *s)
    pool = gen_pool()
    save_rgba(os.path.join(OUT, "blood_pool_sheet.png"), *sheet(pool, 4, 256))
    # Decals can't sample AtlasTexture - each pool stage also ships standalone.
    for i, p in enumerate(pool):
        save_rgba(os.path.join(OUT, f"blood_pool_{i + 1}.png"), *p)

    # contact sheet on jungle-ish grey-green so alpha reads
    bg = np.array([0.42, 0.45, 0.38])
    tiles = mist + splats + pool
    size = 256
    canvas = np.ones((3 * size, 8 * size, 3)) * bg
    slots = [(0, i) for i in range(8)] + [(1, i) for i in range(3)] + [(2, i) for i in range(4)]
    for (r, c), (frgb, fa) in zip(slots, tiles):
        y, x = r * size, c * size
        cell = canvas[y:y + size, x:x + size]
        canvas[y:y + size, x:x + size] = cell * (1 - fa[..., None]) + frgb * fa[..., None]
    Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, "PREVIEW.png"))
    print("blood fx ->", OUT, "(row1 mist x8, row2 splats x3, row3 pool x4)  seed", SEED)


if __name__ == "__main__":
    main()
