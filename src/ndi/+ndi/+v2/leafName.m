function [name, block] = leafName(p)
%LEAFNAME A document's class as the per-leaf V_eta classes named it.
%
%   [NAME, BLOCK] = ndi.v2.leafName(P) for document properties P. Since
%   2026-10-08 (did-schema V_eta_entity_composition_plan.md) a statement's class
%   is its direction with its value kind listed in its superclasses, and the
%   entity classes are one `entity` with a `type`. LEAFNAME names such a
%   document as before:
%     - a statement direction with a value kind: '<kind>_<direction>'
%       ('temperature_observation'), BLOCK the direction;
%     - an entity: 'subject' for the physical types, else its type ('session',
%       'epoch', 'strain'), BLOCK 'entity';
%     - anything else: its own class, BLOCK the same.
%
%   See also ndi.v2.kindOf, ndi.v2.isaQuery.

name = char(p.document_class.class_name);
block = name;
directions = {'assertion', 'observation', 'manipulation', 'calculation'};
if any(strcmp(name, directions))
    supers = p.document_class.superclasses;
    if iscell(supers), supers = [supers{:}]; end
    names = arrayfun(@(s) char(s.class_name), supers, 'UniformOutput', false);
    k = find(strcmp(names, 'base'), 1);
    if ~isempty(k) && k < numel(names) && ~strcmp(names{k + 1}, 'value')
        name = [names{k + 1} '_' name];
    end
elseif strcmp(name, 'entity')
    kind = ndi.v2.kindOf(p);
    if any(strcmp(kind, ndi.v2.entityTypesFor('subject')))
        name = 'subject';
    else
        name = kind;
    end
end
end
