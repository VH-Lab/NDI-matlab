function p = fallbackDir()
%NDI.SCHEMAS.FALLBACKDIR Directory of the bundled fallback schema snapshot.
%
%   P = NDI.SCHEMAS.FALLBACKDIR() returns the directory shipped with
%   the NDI-matlab release that holds the frozen V_epsilon snapshot
%   taken at the current pin. This is the set-version *root* (index.json
%   plus the stable/draft/deprecated tier folders). Used when the user
%   cache is empty and the network is unavailable. The bundle is
%   populated at release time by copying did-schema's `schemas/V_epsilon`
%   tree here.
%
%   See also ndi.schemas.cacheDir, ndi.schemas.activeSchemaPath.

    p = fullfile(ndi.common.PathConstants.CommonFolder, ...
        'schemas', 'fallback', 'V_epsilon');
end
