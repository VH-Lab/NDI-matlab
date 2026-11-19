function q = v1ElementQuery(S, q)
%V1ELEMENTQUERY A search for v1 `element` documents, started from their class.
%
%   Q = ndi.vintage.v1ElementQuery(SESSION, Q) returns Q, a search on the
%   fields of the v1 `element` block (ndi.element/searchquery, getprobes'
%   `element.ndi_element_class`), with `isa element` ANDed on when SESSION's
%   database is a v2 one (did2sqlite); elsewhere Q unchanged.
%
%   The same documents: of NDI's document templates only `element` declares
%   an `element` block (src/ndi/ndi_common/database_documents: element.json
%   is the one file with a top-level "element"), so a document holding
%   `element.name` is an `element`. The order is the database's either way.
%
%   WHY. The `element.*` fields are not queryable in a v2 database, so the
%   search read every document of the session's body: about 0.17 s each,
%   8 of them in one Dab getprobes and 4 in its element facts (the v1
%   element documents a migration carried; NDI-matlab run 44602160692).
%   With `isa element` DID-matlab starts from the class index when the
%   class is small (did2.database.compileQuery, "AN `isa` CAN LEAD").
%   Decided by Jess Haley, 2026-11-06 [read speed margin]
%   (did_v2_go_forward_class_audit.md): reading a migrated session must
%   match or beat v1; VH-Lab/NDI-matlab#1266.
%
%   See also ndi.vintage.elementDoc, ndi.session/getprobes.

try
    isV2 = isa(S.database, 'ndi.database.implementations.database.did2sqlite');
catch
    isV2 = false;
end
if isV2
    q = ndi.query('', 'isa', 'element', '') & q;
end
end
