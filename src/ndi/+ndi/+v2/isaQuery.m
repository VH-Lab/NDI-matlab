function q = isaQuery(className)
%ISAQUERY An `isa` query for a V_eta class under every spelling it has had.
%
%   Q = ndi.v2.isaQuery(CLASSNAME) matches documents of CLASSNAME as written
%   before or after the 2026-10-08 changes, so a reader finds both:
%     - the name it had before the statement rename (ndi.v2.vetaAliases):
%       'assertion' also finds `subject_assertion` documents;
%     - an entity class merged into `entity` (ndi.v2.entityTypesFor): 'subject'
%       also finds entities whose type is a physical kind, 'session' entities of
%       type session;
%     - a statement leaf whose value kind became a mixin: 'temperature_observation'
%       also finds `observation` documents that list `temperature`.
%
%   See also ndi.v2.vetaAliases, ndi.v2.entityTypesFor, ndi.v2.entityQuery.

names = ndi.v2.vetaAliases(className);
q = ndi.query('', 'isa', names{1}, '');
for k = 2:numel(names)
    q = q | ndi.query('', 'isa', names{k}, '');
end
types = ndi.v2.entityTypesFor(className);
if ~isempty(types)
    t = ndi.query('entity.type.name', 'exact_string', types{1}, '');
    for k = 2:numel(types)
        t = t | ndi.query('entity.type.name', 'exact_string', types{k}, '');
    end
    q = q | (ndi.query('', 'isa', 'entity', '') & t);
end
tok = regexp(char(ndi.v2.vetaName(className)), ...
    '^(.+)_(assertion|observation|manipulation|calculation)$', 'tokens', 'once');
if ~isempty(tok)
    direction = ndi.v2.vetaAliases(tok{2});
    d = ndi.query('', 'isa', direction{1}, '');
    for k = 2:numel(direction)
        d = d | ndi.query('', 'isa', direction{k}, '');
    end
    q = q | (d & ndi.query('', 'isa', tok{1}, ''));
end
end
