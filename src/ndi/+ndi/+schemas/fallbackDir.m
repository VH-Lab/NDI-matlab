function p = fallbackDir()
%NDI.SCHEMAS.FALLBACKDIR Directory of the bundled fallback schema snapshot.
%
%   P = NDI.SCHEMAS.FALLBACKDIR() returns the directory shipped with
%   the NDI-matlab release that holds the frozen V_delta snapshot taken
%   at the current pin. Used when the user cache is empty and the
%   network is unavailable.
%
%   See also ndi.schemas.cacheDir, ndi.schemas.activeSchemaPath.

    p = fullfile(ndi.common.PathConstants.CommonFolder, ...
        'schemas', 'fallback', 'stable');
end
