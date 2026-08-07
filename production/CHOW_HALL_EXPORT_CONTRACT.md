# CHOW HALL — EXPORT CONTRACT

**Written 2026-08-07, before the new chow hall is exported, so the first export is the right one.**
Pointer of record: `scripts/world/site_planner.gd:840-843` (occupation map) and `:546` (`_find_markers`).

## The rule the exporter must honour

Marker empties export from Blender as **plain `Node3D`, never `Marker3D`** (`site_planner.gd:543-545`).
Name prefix is **`work_`**, and the convention is `work_<building>_<role>`. Matching is
`begins_with`, so a numeric suffix is free: `work_queue_01`, `work_queue_02`, …

## His loop, stage by stage, against what the code already knows

*"Diners walk up to chow hall, get into line, get food, find a seat and eat. When they are done
they return their tray and then go about their business, leaving the chow hall."* — 2026-08-07

| # | Stage | Marker | Status |
|---|---|---|---|
| 1 | Walk up | `work_chow_trigger` | **mapped** → `mess_hall` |
| 2 | Get into line | `work_queue_NN` | **mapped** → `mess_hall` |
| 3 | Get food | `work_chow_server_line` | **mapped** → `mess_cook` (the man serving) |
| 4 | Find a seat | `work_chow_diner_NN` | **mapped** → `mess_hall` — **these are the seats** |
| 5 | Eat | `work_eat` | **mapped** → `mess_hall` |
| 6 | **Return tray** | — | **THE GAP. Nothing maps to this.** |
| 7 | Leave | `work_chow_exit` | **mapped** → `mess_hall` |

## The one thing to add: a tray return

Stage 6 has an authored clip (`chow_tray_dump`) and **no marker to play it at**. Add one empty at
the scullery / tray drop:

```
work_chow_tray_return
```

I will map it to `mess_hall` on the code side. Without it the chain has to skip the tray return or
fake it at the exit, and his spec names it explicitly.

## Counts that matter

- **`work_queue_NN`** — order is *not* guaranteed by the scene tree, so number them and the code
  sorts by name. Give the line as many points as it should be long (4–6 reads well).
- **`work_chow_diner_NN`** — one per seat, sat *on* the bench, facing the table. The seated clips
  play at the marker's transform, so a marker floating above a bench puts a man in the air.
- **`work_chow_server_line`** — the serving post, behind the counter, facing the queue.

## What does NOT need to change

`chow_server`, `chow_server_line`, `chow_diner`, `chow_trigger`, `chow_exit`, `eat`, `queue` are
already in `FSB_WORK_OCCUPATION`. **Do not rename them** — the mapping is live and the servery side
already works in game.
