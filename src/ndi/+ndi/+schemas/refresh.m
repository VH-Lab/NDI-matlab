function p = refresh(options)
%NDI.SCHEMAS.REFRESH Download schemas at the current pin into the cache.
%
%   P = NDI.SCHEMAS.REFRESH() fetches the DID-schema source tree at the
%   currently pinned ref, extracts the pinned set-version tree (V_epsilon
%   by default: index.json plus the stable/draft/deprecated tier
%   folders), and writes it to ndi.schemas.cacheDir(). Returns the
%   populated cache directory.
%
%   The fetch is idempotent: re-running at the same pin overwrites the
%   same cache directory with identical content. To move the pin, call
%   NDI.SCHEMAS.PIN(REF) first and then NDI.SCHEMAS.REFRESH.
%
%   NDI.SCHEMAS.REFRESH(...,'Force',TF) re-downloads even when the
%   target cache directory is already populated (default false).
%
%   Errors:
%     - NDI:schemas:UnpinnedRefresh - pin.json has no ref set.
%     - NDI:schemas:FetchFailed     - the download or extraction failed.
%
%   See also ndi.schemas.pin, ndi.schemas.init, ndi.schemas.cacheDir.

    arguments
        options.Force (1,1) logical = false
    end

    info = ndi.schemas.pin();
    if isempty(info.ref)
        error('NDI:schemas:UnpinnedRefresh', ...
            ['Cannot refresh: pin has no ref set. Use ' ...
             'ndi.schemas.pin(REF) to set a commit SHA or tag.']);
    end

    p = ndi.schemas.cacheDir(info.ref);
    if ~options.Force && hasSchemas(p)
        return;
    end

    fetchSchemasAtRef(info, p);
end

function tf = hasSchemas(p)
    tf = isfolder(p) && ~isempty(dir(fullfile(p, '*.json')));
end
