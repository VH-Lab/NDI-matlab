function varargout = elementFieldsScope(action, varargin)
%ELEMENTFIELDSSCOPE A cache of migrated elements' fields that lives for ONE call.
%
%   SCOPE = ndi.vintage.elementFieldsScope('open') opens a scope and returns
%   an onCleanup object; the scope closes when it is cleared or goes out of
%   scope. Scopes nest: the cache is emptied when the outermost one closes.
%   While no scope is open nothing is stored and every lookup misses, so a
%   read outside a scope behaves exactly as without this cache.
%
%   ndi.vintage.elementFieldsScope('put', KEY, VALUE) stores VALUE under KEY
%   (only while a scope is open); [VALUE, HIT] =
%   ndi.vintage.elementFieldsScope('get', KEY) reads it back.
%   TF = ndi.vintage.elementFieldsScope('isopen').
%
%   WHY. Rebuilding one migrated element's v1 fields
%   (ndi.vintage.elementFields) takes five database searches, and one
%   getelements / getprobes / epoch-table read asks for the same element's
%   fields several times (the element's class, its fields for the
%   constructor, its probe-map row). Jess Haley, 2026-11-06: "Speed can't
%   be slower than v1"; the reads batch the fields once
%   (ndi.vintage.prefetchElementFields) and every later question in the
%   same call is answered from here. Nothing outlives the call, so a
%   document written afterwards is never answered from a stale entry.
%
%   Keys are built by the callers from the session id and the document id
%   (ndi.vintage.prefetchElementFields).

persistent depth store
if isempty(depth)
    depth = 0;
end
switch action
    case 'open'
        depth = depth + 1;
        if depth == 1 || isempty(store)
            store = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
        varargout{1} = onCleanup(@() ndi.vintage.elementFieldsScope('close'));
    case 'close'
        depth = max(depth - 1, 0);
        if depth == 0
            store = [];
        end
    case 'isopen'
        varargout{1} = depth > 0;
    case 'put'
        if depth > 0
            store(char(varargin{1})) = varargin{2};
        end
    case 'get'
        if depth > 0 && ~isempty(store) && isKey(store, char(varargin{1}))
            varargout{1} = store(char(varargin{1}));
            varargout{2} = true;
        else
            varargout{1} = [];
            varargout{2} = false;
        end
    otherwise
        error('NDI:vintage:elementFieldsScope:badAction', 'Unknown action "%s".', action);
end
end
