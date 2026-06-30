# Deployment / Release Guide — DM Batch Renamer

DM Batch Renamer ships through **ReaPack**, REAPER's package manager. There is no build or
CI step: a "release" is (1) committing the new code to GitHub and (2) appending a new
`<version>` block to `index.xml` that points each shipped file at that commit's raw URL.
Users then get the update via *ReaPack → Synchronize*.

## How distribution works

- `index.xml` (repo root) is a **ReaPack repository index**. Users add the repo URL once
  (Extensions → ReaPack → Import repositories), then install/update from it.
- The index declares one package: `DM_RENAMER_Main.lua` (`type="script"`), with a
  `<version>` history. The newest `<version>` is what ReaPack installs.
- Each `<version>` lists every file to deliver as a `<source>` pointing at a **pinned raw
  GitHub URL** for a specific commit.
- ReaPack installs files relative to the package's action-list location, recreating the
  `Modules/` and `Icons/` subpaths from the `file=` attributes.

## `<source>` attribute conventions (match the existing entries)

| Attribute | Meaning |
|-----------|---------|
| `main="main"` on `DM_RENAMER_Main.lua` | Registers it as a runnable **main** action |
| `main="main"` on the two companion scripts | They are *also* runnable actions (bind to mouse/toolbar) |
| `file="Modules/…"` / `file="Icons/…"` | Installed at that relative path; not a runnable action by itself |

The current package delivers **16 files** per version: the main script, 9 `dofile` modules,
the 2 companion action scripts, and 4 icon PNGs.

## Files that must change on every release

A shipped change requires updating the version in **three coupled places**:

1. **`README.md`** — the line `**Version:** X.Y.Z-beta` (currently line 25).
2. **`index.xml` root** — the `commit="…"` attribute on `<index>` (the release commit hash).
3. **`index.xml` package** — a new `<version name="X.Y.Z-beta" author="Anthony Deneyer"
   time="<ISO-8601 Z>">` block whose `<source>` URLs all use that **same** commit hash.

> Invariant: the commit hash in the root `commit="…"` and the hash inside every new
> `<source>` URL must be identical, and that commit must actually contain the files. In
> v0.7.0-beta both are `ffbbf4e83ea11596ebb7a05875ba06b925705a2c`.

## Release procedure

1. Make and test your code change in `DM Batch Renamer/` (see
   [development-guide.md](./development-guide.md#testing--verification)).
2. Bump the version string in `README.md`.
3. Commit and push the code change. **Note the resulting commit hash** — call it `<HASH>`.
4. In `index.xml`:
   - set `<index … commit="<HASH>">`;
   - copy the previous `<version>` block, bump `name` to the new version, set `time` to the
     current UTC time (`YYYY-MM-DDTHH:MM:SSZ`);
   - replace the commit hash in **every** `<source>` URL of the new block with `<HASH>`;
   - add a `<changelog><![CDATA[ … ]]></changelog>` summarising the change (one line per
     bullet, as in the 0.7.0-beta block at `index.xml:208-210`);
   - if you added/removed/renamed a delivered file, update the `<source>` list accordingly
     (and keep the `main=`/`file=` attributes correct).
5. Commit `index.xml` (and the README bump if not already in `<HASH>`). Push.
6. Verify: in REAPER, *ReaPack → Synchronize packages* should offer the new version and
   install it cleanly with all modules and icons present.

> Because the `<source>` URLs in a version block point at `<HASH>`, that block is only valid
> **after** the code commit exists on GitHub. If you bundle the `index.xml` edit into the
> same commit, its own `<source>` URLs reference the commit being created — which only
> resolves once pushed. Practically: push code, read the hash, then write the index block.
> (Alternatively, do it in two commits and set the index `commit`/URLs to the *code* commit.)

## Versioning convention

Semantic-ish with a `-beta` suffix: `0.MINOR.PATCH-beta`. History runs 0.5.6-beta →
0.7.0-beta. Commit messages are imperative and tag the version, e.g.
`Fix settings not persisting across REAPER restarts (v0.6.8-beta)`.

## What is *not* shipped

`.gitignore` excludes `_bmad-output/` and `.claude/`. The `docs/`, `_bmad/`, and the BMad
tooling are repository-only and are **not** declared in `index.xml`, so they never reach
users. Only the files listed as `<source>` entries are delivered.
