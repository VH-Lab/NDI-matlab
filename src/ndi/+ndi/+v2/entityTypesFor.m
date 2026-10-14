function types = entityTypesFor(className)
%ENTITYTYPESFOR The `entity.type` values a pre-2026-10-08 entity class became.
%
%   TYPES = ndi.v2.entityTypesFor(CLASSNAME). On 2026-10-08 subject, strain,
%   product, software, person, organization, funding, web_resource, dataset,
%   study, publication, session and epoch merged into one `entity` class with a
%   bound `type` (did-schema V_eta_entity_composition_plan.md sec. 4). A
%   `subject` became one of the seven physical kinds, each other class the type
%   of its own name. TYPES is {} for any other name.
%
%   See also ndi.v2.isaQuery, ndi.v2.blockOf.

switch char(className)
    case 'subject'
        types = {'organism', 'culture', 'tissue', 'cell', 'group', 'device', 'material'};
    case {'strain', 'product', 'software', 'person', 'organization', 'funding', ...
            'web_resource', 'dataset', 'study', 'publication', 'session', 'epoch', 'protocol'}
        types = {char(className)};
    otherwise
        types = {};
end
end
