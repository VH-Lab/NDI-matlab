function p = vocabPatterns(kind, patterns, schemaPath)
%VOCABPATTERNS Term patterns widened so a relation / entity type / channel type is found by node.
%
%   P = ndi.v2.vocabPatterns(KIND, PATTERNS) returns PATTERNS (a char or a
%   cellstr, as ndi.v2.termQuery and ndi.v2.matchTerm take them) with, for each
%   pattern that names a handle NDI knows (or its alias, or the name the
%   schema stores for it), that handle's nodes and every name it goes by
%   appended. A pattern with a wildcard, or one NDI does not know, is kept as
%   it is. So `relationDocs(..., 'member_of', ...)` finds a relation stored as
%   {RO:0002350, 'member of'} as well as one stored as {'', 'member_of'}
%   (Jess Haley 2026-10-22 [vocabulary nodes] L1/L2).
%
%   See also ndi.v2.termQuery, ndi.v2.matchTerm, ndi.v2.vocabNodes.

arguments
    kind (1,:) char
    patterns
    schemaPath = getenv('DID_SCHEMA_PATH')
end

if isempty(patterns)
    p = patterns;
    return;
end
p = reshape(cellstr(patterns), 1, []);
V = ndi.v2.vocabNodes(kind, schemaPath);
names = keys(V.nameHandle);
extra = {};
for k = 1:numel(p)
    if ndi.v2.hasWildcard(p{k}) || ~isKey(V.nameHandle, p{k})
        continue;
    end
    h = V.nameHandle(p{k});
    i = find(strcmp(V.handles, h), 1);
    if ~isempty(i)
        extra = [extra, V.nodes{i}]; %#ok<AGROW>
    end
    for j = 1:numel(names)
        if strcmp(V.nameHandle(names{j}), h)
            extra{end+1} = names{j}; %#ok<AGROW>
        end
    end
end
p = unique([p, extra], 'stable');
end
