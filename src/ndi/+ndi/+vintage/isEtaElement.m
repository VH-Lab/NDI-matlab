function tf = isEtaElement(doc, ndi_session_obj)
%ISETAELEMENT True when DOC is a migrated (V_eta) or v2 element.
%
%   TF = ndi.vintage.isEtaElement(DOC, NDI_SESSION_OBJ)
%
%   A v2 element carries no `element` block: on did-schema #73 it is a
%   `subject` (the class map's element row), on #88 an `entity` (T1, type
%   device, cell or Group). An `entity` is an element when data can be read
%   through it, by its links and not by a label (Decided by Jess Haley,
%   2026-11-10 [element recognised by its links], did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): a `device` with a
%   recording observation or a wiring relation is a probe, and a `cell` or
%   `Group` with a `derived_from` relation onto such a probe is a sorted unit
%   (ndi.vintage.elementLinkKind). A device with neither is not a probe, and
%   an entity that is not an element (a session, an animal, an imported
%   instrument with no recording) is never mistaken for one. The same rule
%   holds for migrated and new v2 data.
%
%   FALLBACK, WHERE PRESENT: an entity an `ndi element class` assertion is
%   about is an element too (every element migrated before DID-matlab stops
%   writing that assertion, [ndi element class not kept]); it is asked
%   first, since it is one search and settles the migrated corpora.
%
%   See also ndi.vintage.entryFor, ndi.vintage.elementFields,
%   ndi.vintage.linkedElements.

[entry, vintage] = ndi.vintage.entryFor(doc);
tf = ~isempty(entry) && strcmp(vintage, 'V_eta') && strcmp(entry.concept, 'element');
if tf || isempty(ndi_session_obj)
    return;
end
p = doc.document_properties;
if ~(isfield(p, 'document_class') && strcmp(p.document_class.class_name, 'entity'))
    return;
end
% the call's cache (ndi.vintage.prefetchElementFields), when it holds them
[c, hit] = ndi.vintage.elementFieldsScope('get', ...
    ['c|' char(ndi_session_obj.id()) '|' char(p.base.id)]);
if hit && c.count > 0
    tf = true;
    return;
end
if ~hit
    q = ndi.v2.statementQuery('assertion', 'term') & ...
        ndi.v2.fieldQuery('statement.variable.name', 'exact_string', ...
            ndi.vintage.elementLabel('class')) & ...
        ndi.v2.entityQuery(p.base.id);
    tf = ~isempty(ndi_session_obj.database_search(q));
    if tf
        return;
    end
end
% by its links
tf = ~isempty(ndi.vintage.elementLinkKind(p, ndi_session_obj));
end
