# Quarantined snapshots (not part of the build)

These folders/files are **excluded** by `tsconfig.json` and must not be imported by production code.

| Path | Purpose |
|------|---------|
| `_remote/` | Snapshot synced from a remote host for diffing |
| `_vps_live/` | Snapshot of VPS-live sources for incident comparison |
| `*.patched.ts` | One-off patch drafts (e.g. `drivers.service.patched.ts`) |

## Rules

- Do **not** wire these into `AppModule` or deploy scripts.
- Prefer deleting after merging useful changes into the live `src/*.ts` files.
- Kept for historical/diff reference only — safe to remove once confirmed unused by ops.

Deploy/build uses only the root `src/*.ts` sources (see `exclude` in `tsconfig.json`).
