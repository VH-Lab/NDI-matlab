function p = cacheDir(varargin)
%NDI.SCHEMAS.CACHEDIR User cache directory for a given pin ref.
%
%   P = NDI.SCHEMAS.CACHEDIR() returns the directory for the currently
%   pinned ref: '~/.ndi/schemas/V_delta/<ref>/stable'. If the pin has
%   no ref set the per-ref segment is replaced with 'unpinned'.
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

    if isempty(varargin)
        info = ndi.schemas.pin();
        ref = info.ref;
    else
        ref = char(string(varargin{1}));
    end

    if isempty(ref)
        refSegment = 'unpinned';
    else
        refSegment = sanitize(ref);
    end

    home = char(java.lang.System.getProperty('user.home'));
    p = fullfile(home, '.ndi', 'schemas', 'V_delta', refSegment, 'stable');
end

function s = sanitize(ref)
    s = regexprep(ref, '[^A-Za-z0-9._-]', '_');
end
