function P = relationPasses(schemaPath)
%RELATIONPASSES What passes along each relation, read from the V2 schema's registry.
%
%   P = ndi.v2.relationPasses(SCHEMAPATH) (SCHEMAPATH defaults to
%   DID_SCHEMA_PATH) reads SCHEMAPATH/binding_registry_meta.json. Each
%   `relation_bindings` row declares `passes` (did-schema
%   V_eta_relation_inheritance_plan.md and tenet T17, 2026-10-20, a proposal
%   built ahead of signature), one of:
%     assertions    an assertion about the parent is true of the child
%                   (part_of, sample_of, instance_of; aliquot_of and
%                   passage_of retired into sample_of, [vocabulary nodes] K5)
%     distributive  a statement or relation marked distributive on the group
%                   is true of each member (member_of)
%     context       the parent's interactions overlapping the stay, as
%                   context, never fact (contained_in)
%     nothing       nothing (every other row: included_in, same_as, ...)
%
%   P is a struct of cellstr rows, in the registry's order:
%     assertions, distributive, context, nothing   the relations by value, as
%                   NDI's handles ('part_of'), each row read by its node
%                   (ndi.v2.vocabHandle; Jess Haley 2026-10-22 [vocabulary
%                   nodes] L1), so the stored name may be the label
%     names         every relation the registry binds
%     declared      true when the registry declares `passes` (did-schema #88
%                   and later). A registry that does not (an older schema
%                   copy), or no registry, passes nothing along any relation:
%                   NDI keeps no hard-coded rules of its own.
%
%   Read once per file (path, date and size) and kept for the MATLAB session;
%   `clear ndi.v2.relationPasses` drops it.
%
%   See also ndi.entity.

arguments
    schemaPath = getenv('DID_SCHEMA_PATH')
end

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
f = '';
if ~isempty(schemaPath)
    f = ndi.v2.schemaFile(char(schemaPath), 'binding_registry_meta.json');   % by name, any layout
end
if isempty(f) || ~isfile(f)
    P = fromRows({}, {});
    return;
end
info = dir(f);
key = sprintf('%s|%.12g|%d', f, info.datenum, info.bytes);
if isKey(cache, key)
    P = cache(key);
    return;
end
names = {};
passes = {};
try
    reg = jsondecode(fileread(f));
    rows = {};
    if isfield(reg, 'relation_bindings')
        rows = reg.relation_bindings;
        if isstruct(rows), rows = num2cell(rows); end
    end
    for k = 1:numel(rows)
        r = rows{k};
        if ~isfield(r, 'relation') || ~isstruct(r.relation) || ~isfield(r.relation, 'name')
            continue;
        end
        % NDI's handle for the row's relation, by its node (Jess Haley
        % 2026-10-22 [vocabulary nodes] L1), so P names 'part_of' whether the
        % registry stores 'part_of' or the ontology label 'part of'
        names{end+1} = char(ndi.v2.vocabHandle('relation', r.relation, schemaPath)); %#ok<AGROW>
        v = '';
        if isfield(r, 'passes') && (ischar(r.passes) || isstring(r.passes))
            v = char(r.passes);
        end
        passes{end+1} = v; %#ok<AGROW>
    end
catch
    names = {};
    passes = {};
end
P = fromRows(names, passes);
cache(key) = P;
end

% -----------------------------------------------------------------------------
function P = fromRows(names, passes)
arguments
    names cell
    passes cell
end
P = struct('assertions', {{}}, 'distributive', {{}}, 'context', {{}}, ...
    'nothing', {{}}, 'names', {reshape(names, 1, [])}, ...
    'declared', any(~cellfun(@isempty, passes)));
for k = 1:numel(names)
    v = passes{k};
    if ~any(strcmp(v, {'assertions', 'distributive', 'context'}))
        v = 'nothing';   % the build refuses a row without one; read it as passing nothing
    end
    P.(v){end+1} = names{k};
end
end
