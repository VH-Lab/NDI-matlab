function clearcaches(varargin)
% CLEARCACHES - clear NDI/DID in-memory caches
%
% ndi.database.fun.CLEARCACHES(OBJ1, OBJ2, ...)
%
% Clears the in-memory caches that can hold stale copies of document
% definitions, schemas, or session data during a long-lived MATLAB session.
% This is a development convenience for when document definitions or schemas
% have been edited on disk but a running session is still using cached copies.
%
% Always cleared:
%   * the NDI document-definition memo (a persistent cache inside
%     ndi.document.readblankdefinition) that holds the blank JSON definition of
%     each document type; and
%   * the DID file-cache singleton (the persistent inside did.common.getCache).
%
% Additionally, for each ndi.session (or ndi.cache) passed as an argument, that
% object's ndi.cache is cleared (this holds things like cached epoch tables).
% With no arguments, only the two global caches above are cleared. To clear a
% dataset's cache, pass its linked ndi.session object(s).
%
% Note: DID reads document definitions and schemas fresh (it has no definition
% or schema cache of its own), so the definition memo above lives on the NDI
% side. A full MATLAB restart (or 'clear classes') clears every persistent as
% well, and is the surest reset if anything still looks stale.
%
% Example:
%   ndi.database.fun.clearcaches(S);    % S is an ndi.session
%
% See also: ndi.document, ndi.cache, did.common.getCache

    % 1) NDI document-definition memo (persistent in readblankdefinition)
    ndi.document.readblankdefinition('--clear-cache');

    % 2) DID file-cache singleton (persistent inside did.common.getCache)
    try
        clear('did.common.getCache');
    catch
        % ignore: nothing to clear or not clearable in this context
    end

    % 3) the ndi.cache of any session / dataset / cache passed in
    for i = 1:numel(varargin)
        c = local_cache(varargin{i});
        if ~isempty(c)
            c.clear();
        end
    end

end % clearcaches()

% -------------------------------------------------------------------------

function c = local_cache(obj)
% return the ndi.cache associated with OBJ, or [] if none is reachable
    c = [];
    if isa(obj, 'ndi.cache')
        c = obj;
    elseif isprop(obj, 'cache') && isa(obj.cache, 'ndi.cache')
        c = obj.cache; % ndi.session exposes a public 'cache' property
    end
end % local_cache()
