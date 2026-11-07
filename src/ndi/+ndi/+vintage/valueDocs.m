function docs = valueDocs(S, q, paths, className)
%VALUEDOCS The documents a search matches, as light documents holding only some text fields.
%
%   DOCS = ndi.vintage.valueDocs(SESSION, Q, PATHS, CLASSNAME) is, in the
%   order SESSION.database_search(Q) returns them, one ndi.document per
%   matching document, holding only its base.id, document_class.class_name =
%   CLASSNAME and the text at each plain dot-path of PATHS ('' where it has
%   none), read from the database's text index without decoding the
%   documents (ndi.session/database_search_values). DOCS is [] (not {}) when
%   the database cannot answer this way; the caller then searches as before.
%
%   For readers that use nothing of a document but those fields and its id.
%   Jess Haley, 2026-11-06: "Speed can't be slower than v1."

% the same reader as ndi.vintage.lightDocs, with no edges (its class name is
% the stored one, CLASSNAME only where the database gives none)
docs = ndi.vintage.lightDocs(S, q, paths, {}, className);
end
