function doc = getDocument(container, id)
%GETDOCUMENT The ndi.document with base.id ID in CONTAINER, or [] when absent.
%
%   DOC = ndi.v2.getDocument(CONTAINER, ID); CONTAINER is an ndi.session or
%   ndi.dataset. A session searches its own documents first; a session
%   opened from its dataset (ndi.dataset/open_session) then reaches the
%   dataset-level documents (a strain, a person, software), as
%   ndi.session/database_search_with_dataset does. A session opened from
%   its own folder holds only its own.

arguments
    container
    id
end

doc = [];
if isempty(id), return; end
q = ndi.query('base.id', 'exact_string', char(id), '');
d = container.database_search(q);
if isempty(d) && isa(container, 'ndi.session')
    d = container.database_search_with_dataset(q);
end
if ~isempty(d)
    doc = d{1};
end
end
