function [directed, undirected] = relationNames()
%RELATIONNAMES The relation names the V2 schema binds, directed and undirected.
%
%   [DIRECTED, UNDIRECTED] = ndi.v2.relationNames() reads the bound values of
%   directed_relation.relation and undirected_relation.relation from the
%   schema (did2.schema.cache; did-schema's binding registry). Cellstr rows;
%   empty when the schema has none.

directed = namesOf('directed_relation');
undirected = namesOf('undirected_relation');
end

function n = namesOf(className)
n = {};
try
    s = did2.schema.cache.shared().getClass(className);
catch
    return;
end
fs = s.fields;
if isstruct(fs), fs = num2cell(fs); end
for k = 1:numel(fs)
    f = fs{k};
    if ~isfield(f, 'name') || ~strcmp(f.name, 'relation'), continue; end
    if isfield(f, 'constraints') && isstruct(f.constraints) && isfield(f.constraints, 'binding') ...
            && isfield(f.constraints.binding, 'values')
        v = f.constraints.binding.values;
        if isstruct(v), v = num2cell(v); end
        n = cellfun(@(x) char(x.name), v, 'UniformOutput', false);
        n = reshape(n, 1, []);
    end
end
end
