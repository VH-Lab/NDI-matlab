function p = cacheDir(varargin)
%NDI.SCHEMAS.CACHEDIR User cache directory for a given pin ref.
%
%   P = NDI.SCHEMAS.CACHEDIR() returns the directory for the currently
%   pinned ref: '~/.ndi/schemas/did_v2/<ref>/stable'. If the pin has
%   no ref set the per-ref segment is replaced with 'unpinned'.
%
%   The folder is named after the schema set, `did_v2` ([schema set renamed
%   did_v2] and [V2 database file renamed], Jess Haley, 2026-10-25 and
%   2026-11-01). A cache written under the earlier name, `V_eta`, is still
%   read: see ndi.schemas.legacyCacheDir and ndi.schemas.activeSchemaPath.
%   ndi.schemas.refresh writes only here.
%
%   P = NDI.SCHEMAS.CACHEDIR(REF) overrides the ref.
%
%   The path is returned whether or not the directory exists; callers
%   can `isfolder(p)` to test population.
%
%   See also ndi.schemas.refresh, ndi.schemas.activeSchemaPath.

    arguments (Repeating)
        varargin
    end

    p = cachePathFor('did_v2', varargin{:});
end
