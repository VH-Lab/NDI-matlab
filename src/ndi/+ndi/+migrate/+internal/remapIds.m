function [structs, nReplaced] = remapIds(structs, map)
%REMAPIDS Point every reference to a merged-away id at its survivor.
%   [STRUCTS, N] = ndi.migrate.internal.remapIds(STRUCTS, MAP) walks every body
%   in the cell STRUCTS and replaces each char value (or cellstr element) that
%   EQUALS a key of MAP (a containers.Map, old id -> survivor id) with the
%   survivor id. It walks the WHOLE body, not only `depends_on`: v1 refers to
%   things by id from ordinary fields too (a strain id in an ontologyTableRow
%   `bacteriaStrain` cell, haley/doImport.m:164), and a `depends_on` sweep is
%   not a reference check. A body's own `base.id` is never rewritten. Only an
%   EXACT match is replaced; ids are unique tokens, so a partial match is not
%   a reference. N counts the replacements.

nReplaced = 0;
if isempty(map) || map.Count == 0
    return;
end
for i = 1:numel(structs)
    [structs{i}, k] = walk(structs{i}, map, true);
    nReplaced = nReplaced + k;
end
end

function [v, n] = walk(v, map, isTop)
n = 0;
if ischar(v)
    if ~isempty(v) && size(v, 1) == 1 && isKey(map, v)
        v = map(v);
        n = 1;
    end
elseif iscell(v)
    for k = 1:numel(v)
        [v{k}, m] = walk(v{k}, map, false);
        n = n + m;
    end
elseif isstruct(v)
    f = fieldnames(v);
    for e = 1:numel(v)
        for k = 1:numel(f)
            if isTop && strcmp(f{k}, 'base') && isstruct(v(e).base)
                b = v(e).base;
                bf = fieldnames(b);
                for q = 1:numel(bf)
                    if strcmp(bf{q}, 'id'); continue; end
                    [b.(bf{q}), m] = walk(b.(bf{q}), map, false);
                    n = n + m;
                end
                v(e).base = b;
                continue;
            end
            [v(e).(f{k}), m] = walk(v(e).(f{k}), map, false);
            n = n + m;
        end
    end
end
end
