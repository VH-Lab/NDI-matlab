function types = entityTypesFor(className, schemaPath)
%ENTITYTYPESFOR The `entity.type` values a pre-2026-10-08 entity class became.
%
%   TYPES = ndi.v2.entityTypesFor(CLASSNAME). On 2026-10-08 subject, strain,
%   product, software, person, organization, funding, web_resource, dataset,
%   study, publication, session and epoch merged into one `entity` class with a
%   bound `type` (did-schema V_eta_entity_composition_plan.md sec. 4). A
%   `subject` became one of the physical kinds, each other class the type of
%   its own name. TYPES is {} for any other name.
%
%   The types are read from SCHEMAPATH/binding_registry_meta.json's
%   `entity_type_bindings` (SCHEMAPATH defaults to DID_SCHEMA_PATH), so a type
%   the schema retires (web_resource, did-schema #88) or adds is followed
%   without a change here: a `subject` is every registered type that is not
%   one of the class names above (nor protocol), and any other class maps to
%   its own name only when that name is registered. A schema whose registry
%   has no `entity_type_bindings` uses the list NDI hard-coded until then:
%   organism, culture, tissue, cell, group, device, material for a subject,
%   and the class names above plus protocol. Read once per file (path, date
%   and size); `clear ndi.v2.entityTypesFor` drops it.
%
%   See also ndi.v2.isaQuery, ndi.v2.blockOf.

arguments
    className {mustBeText}
    schemaPath = getenv('DID_SCHEMA_PATH')
end

% the classes merged into `entity`, each the type of its own name
merged = {'strain', 'product', 'software', 'person', 'organization', 'funding', ...
    'web_resource', 'dataset', 'study', 'publication', 'session', 'epoch', 'protocol'};
registered = registeredTypes(schemaPath);
if isempty(registered)
    % no entity_type_bindings: the list NDI hard-coded before the registry gave it
    physical = {'organism', 'culture', 'tissue', 'cell', 'group', 'device', 'material'};
    known = [physical, merged];
else
    physical = setdiff(registered, merged, 'stable');
    known = registered;
end

className = char(className);
if strcmp(className, 'subject')
    types = physical;
elseif any(strcmp(className, merged)) && any(strcmp(className, known))
    types = {className};
else
    types = {};
end
end

% -----------------------------------------------------------------------------
function types = registeredTypes(schemaPath)
%REGISTEREDTYPES The `entity_type_bindings` types of the registry, in order;
%   {} when the schema has no registry or the registry has no such list.
arguments
    schemaPath
end
persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
types = {};
if isempty(schemaPath)
    return;
end
f = ndi.v2.schemaFile(char(schemaPath), 'binding_registry_meta.json');   % by name, any layout
if ~isfile(f)
    return;
end
info = dir(f);
key = sprintf('%s|%.12g|%d', f, info.datenum, info.bytes);
if isKey(cache, key)
    types = cache(key);
    return;
end
try
    reg = jsondecode(fileread(f));
    if isfield(reg, 'entity_type_bindings')
        rows = reg.entity_type_bindings;
        if isstruct(rows), rows = num2cell(rows); end
        for k = 1:numel(rows)
            r = rows{k};
            if isstruct(r) && isfield(r, 'type') && (ischar(r.type) || isstring(r.type))
                % NDI's handle, by the row's node (Jess Haley 2026-10-22
                % [vocabulary nodes] L2): 'dataset' even once the registry
                % stores the ontology label
                node = '';
                if isfield(r, 'node') && (ischar(r.node) || isstring(r.node)), node = char(r.node); end
                types{end+1} = char(ndi.v2.vocabHandle('entity_type', ...
                    struct('node', node, 'name', char(r.type)), schemaPath)); %#ok<AGROW>
            end
        end
    end
catch
    types = {};
end
cache(key) = types;
end
