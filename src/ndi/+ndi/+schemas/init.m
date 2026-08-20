function [p, source] = init(options)
%NDI.SCHEMAS.INIT Point did2.schema.cache at the active V_delta directory.
%
%   [P, SOURCE] = NDI.SCHEMAS.INIT() resolves the schemas directory via
%   ndi.schemas.activeSchemaPath, then calls
%   did2.schema.cache.setSchemaPath(P) so subsequent did2 lookups
%   resolve against NDI's pinned schema set. Returns the path used and
%   a tag identifying its source ('cache', 'fallback', or 'none').
%
%   NDI.SCHEMAS.INIT(...,'Quiet',TF) suppresses the informational
%   warning emitted when no schemas are available (default false).
%
%   When SOURCE is 'none' the function is a no-op: did2.schema.cache
%   is left at its existing path. The caller can still operate on the
%   legacy schemas in ndi_common/schema_documents/ until the loader is
%   populated.
%
%   Typical bootstrap:
%       ndi.schemas.refresh();   % once, to populate the user cache
%       ndi.schemas.init();      % each MATLAB session
%
%   See also ndi.schemas.refresh, ndi.schemas.pin,
%   ndi.schemas.activeSchemaPath, did2.schema.cache.setSchemaPath.

    arguments
        options.Quiet (1,1) logical = false
    end

    [p, source] = ndi.schemas.activeSchemaPath();

    if strcmp(source, 'none')
        if ~options.Quiet
            warning('NDI:schemas:NoSchemas', ...
                ['No V_delta schemas available: user cache (%s) and ' ...
                 'fallback bundle (%s) are both empty. Set a pin and ' ...
                 'call ndi.schemas.refresh() to populate the cache.'], ...
                 ndi.schemas.cacheDir(), ndi.schemas.fallbackDir());
        end
        return;
    end

    if isempty(which('did2.schema.cache'))
        if ~options.Quiet
            warning('NDI:schemas:DID2Missing', ...
                ['did2.schema.cache is not on the path; resolved schemas ' ...
                 'at %s but cannot apply them.'], p);
        end
        return;
    end

    did2.schema.cache.setSchemaPath(p);
end
