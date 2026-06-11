% +schemas  NDI schema loader for DID-schema V_epsilon classes.
%
%   This package sources NDI's class schemas from the canonical
%   DID-schema repository at a project-pinned commit / tag, caches them
%   per-user, and falls back to a frozen snapshot shipped with this
%   NDI release when the cache is empty and the network is unavailable.
%
%   The pinned target is the V_epsilon set-version *root* — the
%   directory holding index.json and the stable/draft/deprecated tier
%   folders — so the did2 schema cache resolves classes across tiers via
%   the index ("index mode"). Retargeting a future set version is just a
%   pin path change; no code change here.
%
%   See docs/v2 in DID-matlab for the V2 wire format, and
%   issue #774 for the loader design.
%
%   Cache layout (per user, version-tagged): the set-version root,
%       ~/.ndi/schemas/V_epsilon/<ref>/{index.json, stable/, draft/, deprecated/}
%
%   Fallback bundle (per NDI release), the set-version root:
%       <ndi_common>/schemas/fallback/V_epsilon/{index.json, <tiers>/}
%
%   Pin file (single source of truth for the targeted DID-schema ref):
%       <ndi_common>/schemas/pin.json
%
% Files:
%   init             - point did2.schema.cache at the active set-version dir.
%   refresh          - download schemas at the current pin into cache.
%   pin              - read or update the DID-schema pin.
%   cacheDir         - user cache dir for a given pin ref.
%   fallbackDir      - bundled fallback schema dir.
%   activeSchemaPath - resolve cache -> fallback to a usable schema dir.
