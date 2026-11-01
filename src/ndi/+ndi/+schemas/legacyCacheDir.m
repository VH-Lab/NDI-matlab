function p = legacyCacheDir(varargin)
%NDI.SCHEMAS.LEGACYCACHEDIR The user cache folder under the set's earlier name.
%
%   P = NDI.SCHEMAS.LEGACYCACHEDIR() is '~/.ndi/schemas/V_eta/<ref>/stable'
%   for the currently pinned ref ('unpinned' when the pin has no ref);
%   P = NDI.SCHEMAS.LEGACYCACHEDIR(REF) overrides the ref.
%
%   The schema set was named `V_eta` before [schema set renamed did_v2]
%   (Jess Haley, 2026-10-25); the cache folder follows the new name
%   (ndi.schemas.cacheDir) and a cache written under the old one is still
%   read when the new one is not populated (ndi.schemas.activeSchemaPath).
%   Nothing writes here.
%
%   See also ndi.schemas.cacheDir, ndi.schemas.activeSchemaPath.

    arguments (Repeating)
        varargin
    end

    p = cachePathFor('V_eta', varargin{:});
end
