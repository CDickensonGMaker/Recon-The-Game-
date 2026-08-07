# Toolkit Surveyor — where a new backend plugs in (audited 2026-08-07)

## 1. Backend plugin contract
`Backend(ABC)` at `mocap_toolkit/backends/base.py:172`. Abstract surface is only:
`capabilities()` (`base.py:210`), `probe(source)` (`base.py:220`), `extract(source, profile, opts,
progress) -> Take` (`base.py:224`). Optional `doctor()`/`close()`. Class vars incl. `licence` and
`commercial_use` (defaults **False** deliberately; `licence_note()` stamps it into the take,
`base.py:196-208`). Registration is one line in `ENTRIES` (`registry.py:16-21`), lazy import so a
backend with missing deps stays listable. **A stubbed `rtmw` backend already exists**
(`backends/rtmw/__init__.py`, 168 lines, extract stubbed, documents its own venv:
`py -3.12 -m venv venvs/rtmw` at `:41-49`).

## 2. What take.json holds
- Multiple cameras: **NO** — `Take.camera` is a single unvalidated dict (`take.py:152`).
- Extrinsics: **NONE** — camera block is opaque passthrough; MediaPipe fabricates it
  (`fov_deg=60 assumed`, `mediapipe/__init__.py:535-545`).
- Per-joint confidence: YES (stride-1 channel, `take.py:396-404`; 0.0 = missing).
- Spaces: 3D only (`body`/`world`, `take.py:49`); **no 2D/image-space channel exists**.
  `world` requires a `root` channel (`take.py:318-321`).

## 3. Existing calibration/triangulation code
**None.** Repo-wide grep: only the unused `"input.multi_view"` capability string (`base.py:39`),
prose saying we don't do it (`docs/FILMING.md:20`), and MediaPipe's assumed-FOV disclaimers.
`umeyama.py` (similarity fit) is the only reusable geometry helper.

## 4. Where MediaPipe's 3D comes from
The model's **statistical prior**, not measurement — `world` landmarks, hip-origin metres
(`landmarks.py:94-126`); `image` (2D) landmarks are computed but used only for the preview overlay.
`depth.py` exists purely to SUPPRESS untrusted depth. This is the wall the whole question is about.

## 5. Minimal `triangulated` backend
- Contract code (~150-200 lines patterned on rtmw) + one registry line. `input.multi_view` already
  in the capability vocabulary — no protocol bump.
- Second video arrives via `opts.extra` (`base.py:132`) — CLI takes one positional source (`cli.py:460`).
- Greenfield: calibration (intrinsics+extrinsics pair, ~250-400 lines with OpenCV wrappers + calib
  JSON format), DLT triangulation + reprojection-error→confidence (~250-350 lines), temporal sync
  between clips (genuinely hard without genlock), plumbing MediaPipe's 2D `image` landmarks out of
  the preview-only path.
- Downstream untouched: addon, take.py, runner all keep working if we emit `space="body"` or
  `world`+root in Blender convention (`addon/take_io.py:290-303`).

## 6. Venvs / selection
One venv today (`venvs/mediapipe`, Settings hold a single `venv` string, `app/config.py:38`).
Two venvs coexist fine on disk; the rtmw backend documents that pattern. But nothing selects a venv
per backend, and running two solvers in ONE extract invocation is unsupported (composite exists but
is excluded from auto-selection, `cli.py:98-106`).

## Effort estimate
~700-1100 new lines across 3-4 files; only ~200 is contract. **1-2 days to a prototype** with a
hand-authored calib and manually-synced clips; **1-2 weeks** to make calibration, sync and
confidence trustworthy enough that measured depth actually beats MediaPipe's prior — which is the
only reason to build it. Format friction: two cameras + extrinsics either go in the unvalidated
`camera` dict (works today, addon ignores it) or a real `cameras: [...]` MINOR format bump.
