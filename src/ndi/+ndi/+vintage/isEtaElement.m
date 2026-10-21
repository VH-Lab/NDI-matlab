function tf = isEtaElement(doc, ndi_session_obj)
%ISETAELEMENT True when DOC is a migrated (V_eta) element.
%
%   TF = ndi.vintage.isEtaElement(DOC, NDI_SESSION_OBJ)
%
%   A migrated element carries no `element` block: on did-schema #73 it is a
%   `subject` (the class map's element row), on #88 an `entity` (T1, type
%   device, ...). Either way it is the document an `ndi element class`
%   assertion is about (ndi.vintage.elementSubjectIds). The `entity` case is
%   decided by that assertion, so an entity that is not an element (a session,
%   an animal) is never mistaken for one.
%
%   See also ndi.vintage.entryFor, ndi.vintage.elementFields.

[entry, vintage] = ndi.vintage.entryFor(doc);
tf = ~isempty(entry) && strcmp(vintage, 'V_eta') && strcmp(entry.concept, 'element');
if tf || isempty(ndi_session_obj)
    return;
end
p = doc.document_properties;
if ~(isfield(p, 'document_class') && strcmp(p.document_class.class_name, 'entity'))
    return;
end
q = ndi.v2.statementQuery('assertion', 'term') & ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', ...
        ndi.vintage.elementLabel('class')) & ...
    ndi.v2.entityQuery(p.base.id);
tf = ~isempty(ndi_session_obj.database_search(q));
end
