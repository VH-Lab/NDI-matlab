function p = tilePath(session, doc, filename)
% TILEPATH - local path of a document's binary file, remembered between calls
%
%   P = ndi.fun.doc.gene.TILEPATH(SESSION, DOC, FILENAME)
%   ndi.fun.doc.gene.TILEPATH('clear')
%
%   Returns the local path of one of DOC's binary files, fetching it if it
%   is remote, and REMEMBERS the answer so the next call for the same file
%   is a single isfile check.
%
%   WHY REMEMBERING IS SAFE. The database names a cached file by its
%   immutable uid, so the path for a given (document, filename) cannot
%   change meaning: the file is either still there or it is gone, never
%   different. That is what makes a memo correct here and would not be
%   true of a path derived from mutable state.
%
%   WHAT IT IS AND IS NOT WORTH, stated plainly because the obvious story
%   is the wrong one. There is NO MATLAB viewer for these pyramids: the
%   only callers of readViewport and exportRegion are readViewportBase and
%   the tests, and interactive viewing is napari's, through NDI-python. So
%   this saves nothing for a viewer that pans, because there is none.
%
%   What it does save is a REPEATED PROGRAMMATIC READ: a sweep over
%   overlapping rectangles, an export run for several gene subsets over
%   one region, a montage. Each of those opens every tile it touches on
%   every call, and each open is a document read plus a location resolve.
%   It is NOT a download saved -- a cloud-backed session's own cache
%   already prevents a second retrieval of the same file -- so the win is
%   modest and local, not the difference between usable and not.
%
%   The Python side's equivalent is worth more, because napari does
%   re-render on every gene toggle and there the memo also keeps the
%   fetch off a thread that may not touch the session.
%
%   THE FILE CAN STILL DISAPPEAR, which is why the remembered path is
%   CHECKED rather than trusted -- and what happens then depends on what
%   the path is. On a DIRECTORY-BACKED session the path IS the stored
%   file, not a copy of it, so a file that has gone is data that is gone
%   and the database says so. On a CLOUD-BACKED session the local file is
%   a cache copy, and asking again re-fetches it.
%
%   Either way the memo does not hand back a path that has stopped
%   resolving. Trusting it would move the failure to whoever read the
%   file, where a missing tile would look like a corrupt one.
%
%   Inputs:
%   SESSION  - an ndi.session or ndi.dataset
%   DOC      - the ndi.document owning the file
%   FILENAME - the file's name within the document, e.g. 'tile.bin_12'
%
%   Outputs:
%   P - full path to a local, readable copy
%
%   Passing the single argument 'clear' empties the memo. Nothing needs
%   this in normal use -- the entries are short strings and an eviction
%   corrects itself -- but a long-lived session that has walked several
%   large pyramids can reclaim them.
%
%   Example:
%       p = ndi.fun.doc.gene.tilePath(S, tileDoc, 'tile.bin_0');
%       t = ndi.fun.doc.gene.readTileFile(p);
%
%   See also: ndi.fun.doc.gene.readViewport, ndi.fun.doc.gene.exportRegion,
%             ndi.fun.doc.gene.readTileFile

persistent MEMO

if isempty(MEMO)
    MEMO = containers.Map('KeyType','char','ValueType','char');
end

if nargin == 1 && (ischar(session) || isstring(session)) && strcmpi(session,'clear')
    MEMO = containers.Map('KeyType','char','ValueType','char');
    p = '';
    return;
end

if nargin < 3
    error('NDI:gene:tilePath:nargin', ...
        'TILEPATH takes (SESSION, DOC, FILENAME), or the single input ''clear''.');
end
if ~(ischar(filename) || isstring(filename))
    error('NDI:gene:tilePath:filename', 'FILENAME must be text.');
end

key = [doc.id() '/' char(filename)];
if isKey(MEMO, key)
    p = MEMO(key);
    if isfile(p)
        return;
    end
    % Gone since we last looked. Drop it and fetch again rather than
    % handing back a path that no longer resolves.
    remove(MEMO, key);
end

bd = session.database_openbinarydoc(doc, char(filename));
cl = onCleanup(@() session.database_closebinarydoc(bd));
p = bd.fullpathfilename;
clear cl;

MEMO(key) = p;

end % tilePath
