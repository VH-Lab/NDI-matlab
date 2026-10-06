function doc = getDocument(container, id)
%GETDOCUMENT The ndi.document with base.id ID in CONTAINER, or [] when absent.
%
%   DOC = ndi.v2.getDocument(CONTAINER, ID); CONTAINER is an ndi.session or
%   ndi.dataset. A session searches only its own documents: a dataset-level
%   document (a person, a study) is found from the dataset.

doc = [];
if isempty(id), return; end
d = container.database_search(ndi.query('base.id', 'exact_string', char(id), ''));
if ~isempty(d)
    doc = d{1};
end
end
