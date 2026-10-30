% +schemas  NDI schema loader for DID-schema V_eta classes.
%
%   This package sources NDI's class schemas from the canonical
%   DID-schema repository at a project-pinned commit / tag, caches them
%   per-user, and falls back to a frozen snapshot shipped with this
%   NDI release when the cache is empty and the network is unavailable.
%
%   See docs/v2 in DID-matlab for the V_eta wire format, and
%   issue #774 for the loader design.
%
%   Cache layout (per user, version-tagged):
%       ~/.ndi/schemas/V_eta/<ref>/stable/*.json
%
%   Fallback bundle (per NDI release):
%       <ndi_common>/schemas/fallback/stable/*.json
%
%   Pin file (single source of truth for the targeted DID-schema ref):
%       <ndi_common>/schemas/pin.json
%
% Files:
%   init             - point did2.schema.cache at the active V_eta dir.
%   refresh          - download schemas at the current pin into cache.
%   pin              - read or update the DID-schema pin.
%   cacheDir         - user cache dir for a given pin ref.
%   fallbackDir      - bundled fallback schema dir.
%   activeSchemaPath - resolve cache -> fallback to a usable schema dir.
%   setFiles         - the schema files of a did-schema tree, tiered or flat.
