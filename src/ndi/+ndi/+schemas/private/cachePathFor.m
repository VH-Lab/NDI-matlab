function p = cachePathFor(setName, varargin)
%CACHEPATHFOR '~/.ndi/schemas/<setName>/<ref>/stable' for a pin ref.
%   Shared by ndi.schemas.cacheDir (set name did_v2) and
%   ndi.schemas.legacyCacheDir (its earlier name, V_eta). With no ref
%   argument the current pin's ref is used; an empty ref is 'unpinned'.

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
    p = fullfile(home, '.ndi', 'schemas', setName, refSegment, 'stable');
end

function s = sanitize(ref)
    s = regexprep(ref, '[^A-Za-z0-9._-]', '_');
end
