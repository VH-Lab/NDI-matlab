function t = elementEntityType(doc)
%ELEMENTENTITYTYPE NDI's handle for an entity's type ('device', 'cell', 'group', ...).
%
%   T = ndi.vintage.elementEntityType(DOC) reads `entity.type` of DOC (an
%   ndi.document or a struct of document properties) by node, then by name
%   (ndi.v2.vocabHandle; Jess Haley 2026-10-22 [vocabulary nodes] L2), so
%   `Group` (NCIT:C43359) reads 'group'. T is '' for a document that is not
%   an `entity` or carries no type.
%
%   See also ndi.vintage.linkedElements, ndi.vintage.elementLinkKind.

t = '';
if isstruct(doc) && isfield(doc, 'document_properties')
    p = doc.document_properties;   % a document read as a struct
else
    p = ndi.v2.props(doc);
end
if ~isstruct(p) || ~isfield(p, 'document_class') || ~isstruct(p.document_class) ...
        || ~strcmp(char(p.document_class.class_name), 'entity')
    return;
end
if ~isfield(p, 'entity') || ~isstruct(p.entity) || ~isfield(p.entity, 'type') ...
        || isempty(p.entity.type)
    return;
end
t = char(ndi.v2.vocabHandle('entity_type', p.entity.type));
end
