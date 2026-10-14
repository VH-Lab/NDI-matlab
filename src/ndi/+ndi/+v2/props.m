function p = props(doc)
%PROPS The document properties of DOC (an ndi.document, a did2.document or a struct).
%
%   P = ndi.v2.props(DOC)
%
%   See also ndi.entity, ndi.statement.

if isa(doc, 'ndi.document')
    p = doc.document_properties;
elseif isa(doc, 'did2.document')
    p = doc.documentProperties;
elseif isstruct(doc)
    p = doc;
else
    error('ndi:v2:badDocument', 'Expected an ndi.document, did2.document or struct, got %s.', class(doc));
end
end
