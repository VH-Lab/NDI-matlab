function kind = elementLinkKind(doc, S)
%ELEMENTLINKKIND What kind of element an entity is, by its links ('' if none).
%
%   KIND = ndi.vintage.elementLinkKind(DOC, SESSION) is 'probe', 'unit',
%   'ensemble' or '' for the entity DOC (an ndi.document or a struct of its
%   properties), by the rule ndi.vintage.linkedElements states (Decided by
%   Jess Haley, 2026-11-10 [element recognised by its links] and [ensemble
%   has members], did-schema docs/plans/did_v2_go_forward_class_audit.md):
%
%     'probe'     a `device` with a recording observation (an observation
%                 naming it as `instrument_id`) or a wiring relation
%                 (`connected to`, RO:0002170, of which it is the child)
%     'unit'      a `cell` or `Group` that is the child of a `derived_from`
%                 relation onto such a probe
%     'ensemble'  such a `Group` with `member_of` relations into it
%     ''          anything else, a device with neither link included
%
%   Inside a call's scope (ndi.vintage.elementFieldsScope) the answer is the
%   session-wide one, ndi.vintage.linkedElements, read once per call; that
%   one asks only about entities no "ndi element class" assertion is about
%   (the assertion decides while it is written, [assertion wins while
%   written]), so it is '' for those.
%   Outside one, DOC's own links are searched (a few searches, each limited
%   to DOC by its edges).
%
%   See also ndi.vintage.linkedElements, ndi.vintage.elementClassOfKind.

kind = '';
if isempty(S)
    return;
end
if isstruct(doc) && isfield(doc, 'document_properties')
    p = doc.document_properties;
else
    p = ndi.v2.props(doc);
end
if ~isfield(p, 'base') || ~isfield(p.base, 'id')
    return;
end
id = char(p.base.id);
if ndi.vintage.elementFieldsScope('isopen')
    % the session-wide answer already checked each element's entity type
    L = ndi.vintage.linkedElements(S);
    if isKey(L.kind, id)
        kind = L.kind(id);
    end
    return;
end
t = ndi.vintage.elementEntityType(p);
if ~any(strcmp(t, {'device', 'cell', 'group'}))
    return;
end

switch t
    case 'device'
        if isProbe(S, id)
            kind = 'probe';
        end
    otherwise
        rows = edgeRows(S, elementRelationQuery('derived_from') & ...
            (ndi.query('', 'depends_on', 'child_id', id) | ...
             ndi.query('', 'depends_on', 'child', id)), {'parent_id', 'parent'});
        parents = unique({rows.document_id}, 'stable');
        parents = parents(~cellfun(@isempty, parents));
        if isempty(parents)
            return;
        end
        byId = ndi.vintage.docsById(S, parents, 'RawBlocks', {'base', 'entity'}, ...
            'LightClass', 'entity');
        for k = 1:numel(parents)
            d = byId(parents{k});
            if ~isempty(d) && strcmp(ndi.vintage.elementEntityType(d), 'device') ...
                    && isProbe(S, parents{k})
                kind = 'unit';
                break;
            end
        end
        if strcmp(kind, 'unit') && strcmp(t, 'group')
            members = edgeRows(S, elementRelationQuery('member_of') & ...
                (ndi.query('', 'depends_on', 'parent_id', id) | ...
                 ndi.query('', 'depends_on', 'parent', id)), {'parent_id', 'parent'});
            if ~isempty(members)
                kind = 'ensemble';
            end
        end
end
end

function tf = isProbe(S, id)
% a recording observation made with ID, or a wiring relation from it
rows = edgeRows(S, ndi.v2.isaQuery('observation') & ...
    ndi.query('', 'depends_on', 'instrument_id', id), {'instrument_id'});
tf = ~isempty(rows);
if tf
    return;
end
rows = edgeRows(S, elementRelationQuery('connected_to') & ...
    (ndi.query('', 'depends_on', 'child_id', id) | ...
     ndi.query('', 'depends_on', 'child', id)), {'child_id', 'child'});
tf = ~isempty(rows);
end
