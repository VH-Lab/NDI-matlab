# NDI schema loader files

This directory holds NDI-matlab's pin on the canonical DID-schema
V_delta schemas and a frozen fallback snapshot used when the user cache
is empty and the network is unavailable.

## Contents

- `pin.json` — declares the DID-schema commit SHA / tag this NDI release
  targets, along with the repository and source path. Bumped only by
  `ndi.schemas.pin(...)` or as part of an NDI release.
- `fallback/stable/` — frozen snapshot of the schemas pulled at the
  pinned ref. Populated by the release process; intentionally empty
  in a fresh checkout. The user cache at `~/.ndi/schemas/V_delta/<ref>`
  is preferred; this directory is the offline fallback.

See `+ndi/+schemas/` for the loader implementation and issue
[#774](https://github.com/VH-Lab/NDI-matlab/issues/774) for the design.
