# Deployment / Release Guide — DM Batch Renamer

DM Batch Renamer ships through **ReaPack**, REAPER's package manager. There is no build and no
CI step. A release is: commit the code with updated ReaPack headers, regenerate `index.xml`
with the `reapack-index` tool, then push. Users get the update via *ReaPack → Synchronize*.

> `index.xml` is **generated output**. Never edit it by hand. Everything ReaPack shows the user
> — version, changelog, file list, description — comes from the comment header of
> `DM Batch Renamer/DM_RENAMER_Main.lua`. Change the header, regenerate the index.

## Where the package metadata lives

The header of `DM_RENAMER_Main.lua` (lines 1-23) is the single source of truth:

| Tag | Role |
|-----|------|
| `@description` | Package name shown in ReaPack |
| `@author` | Anthony Deneyer |
| `@version` | The release version — `0.MINOR.PATCH-beta` |
| `@changelog` | Notes for **this** version, one line per bullet |
| `@provides` | Every additional file delivered, one per line |
| `@link`, `@about` | GitHub link and the README-style blurb in ReaPack's package panel |

### `@provides` entries

Each line is a repo-relative path with a flag:

- `[main]` — installed **and** registered as a runnable action the user can bind to a key or
  toolbar. The three companion scripts use this.
- `[nomain]` — installed as a plain file, never an action. All `Modules/*.lua` helpers and
  `Icons/*.png` use this.

`DM_RENAMER_Main.lua` itself is the package, so it is not listed. The current release delivers
**18 files**: the main script, 17 `@provides` entries (13 modules + 4 icons).

> A new file under `Modules/` or `Icons/` that is not added to `@provides` is simply never
> delivered. It works locally — where the file exists on disk — and breaks at `dofile` for every
> user who installs. Add the entry in the same change that adds the file.

## Release procedure

1. Make and test the change in `DM Batch Renamer/` (see
   [development-guide.md](./development-guide.md#testing--verification)).

2. Update the header of `DM_RENAMER_Main.lua`:
   - rewrite `@changelog` to describe this release;
   - bump `@version`;
   - add or remove `@provides` lines if the delivered file set changed.

   **`@changelog` and `@version` must move in the same commit.** `reapack-index` reads a
   version's changelog from the commit where `@version` first held that value. Bump the version
   without touching the changelog and the generated index carries the *previous* release's
   notes — recoverable only by hand-editing the XML or rewriting history.

3. Keep the version string in sync in its three homes:

   | File | Location |
   |------|----------|
   | `DM Batch Renamer/DM_RENAMER_Main.lua` | `-- @version` (line 3) |
   | `DM Batch Renamer/DM_RENAMER_Main.lua` | `local DM_RENAMER_VERSION` (line 48) — the string shown in the UI footer |
   | `README.md` | the `**Version:**` line (line 26) |

4. Commit the code change.

5. Regenerate the index from the **repo root**:

   ```bash
   reapack-index --no-commit
   ```

   This reads git **commits** — untracked and gitignored tooling is invisible to it, which is
   what makes it safe here.

   > Do **not** use `reapack-index --check`. It scans the whole working tree, ignores
   > `.gitignore`, and fails on the `.py` files under `_bmad/` and `.claude/`.

6. Review `git diff index.xml`. Expect exactly one new `<version>` block plus an updated
   `commit=` on the root `<index>` element. Anything else means the header was wrong — fix the
   header and regenerate, never patch the XML.

7. Commit `index.xml` and push. The `<source>` URLs point at the raw GitHub URL for the release
   commit, so they only resolve once that commit is on GitHub.

8. Verify: in REAPER, *ReaPack → Synchronize packages* should offer the new version and install
   it cleanly, with every module and icon present.

## One release, one version bump

One `@version` value produces one `<version>` block in the index. Bumping the version several
times while working produces several ReaPack releases, each with a partial changelog. Decide up
front whether a batch of work ships as one release or several, and bump once per release — at
the end, after the change is validated.

## Versioning convention

Semantic-ish with a `-beta` suffix: `0.MINOR.PATCH-beta`. Feature work bumps MINOR, fixes bump
PATCH. Commit messages follow Conventional Commits (`feat(ui):`, `fix(renamer):`,
`chore: bump version to X.Y.Z-beta`).

## What is *not* shipped

`.gitignore` excludes `_bmad-output/`, `_bmad/`, and `.claude/`. Those, plus `docs/`, are
repository-only: they are not in `@provides`, so they never reach users. Only the main script
and the `@provides` entries are delivered.

## Agent note

Automated agents prepare the header and stop there — they do not run `reapack-index`, do not
edit or commit `index.xml`, and do not push. See `AGENTS.md` at the repo root.
