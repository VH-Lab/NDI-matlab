function P = relationPasses(schemaPath)
%RELATIONPASSES What passes along each relation, read from the V2 schema's registry.
%
%   P = ndi.v2.relationPasses(SCHEMAPATH) (SCHEMAPATH defaults to
%   DID_SCHEMA_PATH) reads SCHEMAPATH/binding_registry_meta.json. Each
%   `relation_bindings` row declares `passes` (did-schema
%   V_eta_relation_inheritance_plan.md and tenet T17, 2026-10-20, a proposal
%   built ahead of signature), one of:
%     assertions    an assertion about the parent is true of the child
%                   (part_of, sample_of, aliquot_of, passage_of, instance_of)
%     distributive  a statement or relation marked distributive on the group
%                   is true of each member (member_of)
%     context       the parent's interactions overlapping the stay, as
%                   context, never fact (contained_in)
%     nothing       nothing (every other row: included_in, same_as, ...)
%
%   P is a struct of cellstr rows, in the registry's order:
%     assertions, distributive, context, nothing   the relation names by value
%     names         every relation the registry binds
%     declared      true when the registry declares `passes`; false on a schema
%                   built before it (did-schema main), when the four lists are
%                   the rules NDI hard-coded until then (assertions: part_of,
%                   sample_of, aliquot_of, passage_of, instance_of;
%                   distributive: member_of; context: contained_in) and every
%                   other bound relation passes nothing. No registry gives
%                   those lists and NAMES empty.
%
%   Read once per file (path, date and size) and kept for the MATLAB session;
%   `clear ndi.v2.relationPasses` drops it.
%
%   See also ndi.entity, ndi.v2.recordRelation.

arguments
    schemaPath = getenv('DID_SCHEMA_PATH')
end

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
f = '';
if ~isempty(schemaPath)
    f = fullfile(char(schemaPath), 'binding_registry_meta.json');
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
        names{end+1} = char(r.relation.name); %#ok<AGROW>
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
if ~P.declared
    % the rules NDI hard-coded before the registry declared them
    P.assertions = {'part_of', 'sample_of', 'aliquot_of', 'passage_of', 'instance_of'};
    P.distributive = {'member_of'};
    P.context = {'contained_in'};
    P.nothing = setdiff(P.names, [P.assertions, P.distributive, P.context], 'stable');
    return;
end
for k = 1:numel(names)
    v = passes{k};
    if ~any(strcmp(v, {'assertions', 'distributive', 'context'}))
        v = 'nothing';   % the build refuses a row without one; read it as passing nothing
    end
    P.(v){end+1} = names{k};
end
end
