function [p, source] = activeSchemaPath()
%NDI.SCHEMAS.ACTIVESCHEMAPATH Resolve the schema directory to load from.
%
%   [P, SOURCE] = NDI.SCHEMAS.ACTIVESCHEMAPATH() returns the directory
%   ndi.schemas.init() will hand to did2.schema.cache.setSchemaPath
%   and a tag describing where it came from:
%
%       'cache'    - user cache populated at the current pin (under
%                    did_v2, else under the earlier name V_eta)
%       'fallback' - bundled snapshot shipped with this release
%       'none'     - neither populated; P is '' (loader cannot run)
%
%   The resolver prefers the user cache because it tracks the pin
%   exactly. A schemas directory counts as populated when it exists
%   and contains at least one `*.json` file.
%
%   See also ndi.schemas.init, ndi.schemas.cacheDir,
%   ndi.schemas.fallbackDir.

    cacheP    = ndi.schemas.cacheDir();
    fallbackP = ndi.schemas.fallbackDir();

    if hasSchemas(cacheP)
        p = cacheP;
        source = 'cache';
        return;
    end

    % a cache written under the set's earlier name, V_eta, before
    % [schema set renamed did_v2]: read when the did_v2 one is not populated
    legacyP = ndi.schemas.legacyCacheDir();
    if hasSchemas(legacyP)
        p = legacyP;
        source = 'cache';
        return;
    end

    if hasSchemas(fallbackP)
        p = fallbackP;
        source = 'fallback';
        return;
    end

    p = '';
    source = 'none';
end

function tf = hasSchemas(p)
    if ~isfolder(p)
        tf = false;
        return;
    end
    tf = ~isempty(dir(fullfile(p, '*.json')));
end
