function [p, source] = activeSchemaPath()
%NDI.SCHEMAS.ACTIVESCHEMAPATH Resolve the schema directory to load from.
%
%   [P, SOURCE] = NDI.SCHEMAS.ACTIVESCHEMAPATH() returns the directory
%   ndi.schemas.init() will hand to did2.schema.cache.setSchemaPath
%   and a tag describing where it came from:
%
%       'cache'    - user cache populated at the current pin
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
