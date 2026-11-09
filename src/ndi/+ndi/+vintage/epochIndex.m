function varargout = epochIndex(action, S, varargin)
%EPOCHINDEX The derived epoch-table index of a migrated session's database.
%
%   Jess Haley, 2026-11-09: "Build the derived index" ([1 yes, 2 a, 3 yes]).
%   Rows computed from the documents only -- per acquisition system, per
%   epoch, the probe map (ndi.vintage.ingestedEpochs) and the clocks
%   (ndi.vintage.ingestedArchives) -- kept in DID-matlab's derived-row store
%   (did2.database.sqlitedb/derivedPut) beside the documents, never as a
%   document. Each row records the ids of the documents it was read from;
%   adding or removing any of them, or any document pointing at one,
%   drops the row in the same transaction, and the next read computes it
%   again. NDI-matlab is the only writer of these rows (this function).
%
%   TF = ndi.vintage.epochIndex('available', S): S's database keeps derived
%       rows (a v2 database and a DID-matlab with derivedRowsAvailable),
%       and the index is not switched off (NDI_EPOCH_INDEX=off).
%   M = ndi.vintage.epochIndex('get', S, NAMESPACE, SCOPE, KEYS): a
%       containers.Map key -> decoded value (a struct) for the keys with a
%       current row.
%   ndi.vintage.epochIndex('put', S, NAMESPACE, SCOPE, KEYS, VALUES, DEPS):
%       store rows (VALUES a cell of structs, DEPS a cell of cellstrs).
%   ndi.vintage.epochIndex('clear', S): drop every row of the index.
%
%   See also ndi.vintage.ingestedEpochs, ndi.vintage.ingestedArchives,
%   ndi.vintage.epochIndexBuild.

VERSION = 'ndi-epoch-index-1';
switch action
    case 'available'
        tf = false;
        if strcmpi(getenv('NDI_EPOCH_INDEX'), 'off')
            varargout{1} = tf;
            return;
        end
        try
            tf = ismethod(S, 'database_derived') && S.database_derived('available');
        catch
            tf = false;
        end
        varargout{1} = tf;
    case 'get'
        [ns, scope, keys] = varargin{1:3};
        m = containers.Map('KeyType', 'char', 'ValueType', 'any');
        rows = S.database_derived('getMany', ns, scope, keys, VERSION);
        for k = 1:numel(rows)
            m(rows(k).key) = jsondecode(rows(k).value);
        end
        varargout{1} = m;
    case 'put'
        [ns, scope, keys, values, deps] = varargin{1:5};
        if isempty(keys)
            return;
        end
        texts = cellfun(@(v) jsonencode(v), values, 'UniformOutput', false);
        S.database_derived('putMany', ns, scope, keys, texts, VERSION, deps);
    case 'clear'
        S.database_derived('clear', 'ndi.epochs.navigator');
        S.database_derived('clear', 'ndi.epochs.reader');
    otherwise
        error('NDI:vintage:epochIndex:badAction', 'Unknown action "%s".', action);
end
end
