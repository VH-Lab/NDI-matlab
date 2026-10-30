function link = sessionLinkOf(p)
%SESSIONLINKOF How a session is in a V2 dataset, read from its membership relation.
%
%   LINK = ndi.v2.sessionLinkOf(P), P the properties of a `directed_relation`
%   (a struct, or an ndi.document / did2.document). The relation
%   ndi.v2.sessionLinkRelation writes records in its method how the session is
%   in the dataset (Jess Haley 2026-10-29 [linked session link details],
%   did-schema V_eta_go_forward_class_audit.md). LINK is a struct:
%
%     kind            'linked'   method "database linking" (EMPTY:0000400)
%                     'ingested' method "database ingestion" (EMPTY:0000399)
%                     ''         any other relation (no such method)
%     path            the Pathname parameter (NCIT:C47922), as stored: relative
%                     to the dataset's folder or absolute
%                     (ndi.v2.resolveLinkPath reads it); '' when absent
%     software_class  the "software class" parameter (EMPTY:0000401), e.g.
%                     'ndi.session.dir'; '' when absent
%     child_id        the relation's child (the session entity), '' if none
%     parent_id       its parent (the dataset, or a study), '' if none
%
%   Terms are compared by node, or by the registered name (ndi.v2.matchTerm),
%   so a CURIE written in another accepted spelling still reads.
%
%   See also ndi.v2.sessionLinkRelation, ndi.v2.datasetSessions.

arguments
    p
end

link = struct('kind', '', 'path', '', 'software_class', '', 'child_id', '', 'parent_id', '');
if isa(p, 'ndi.document') || isa(p, 'did2.document')
    p = ndi.v2.props(p);
end
if ~isstruct(p) || isempty(p)
    return;
end
c = ndi.v2.edgeIds(p, 'child_id');
if ~isempty(c), link.child_id = char(c{1}); end
c = ndi.v2.edgeIds(p, 'parent_id');
if ~isempty(c), link.parent_id = char(c{1}); end

m = ndi.v2.methodOf([], p, 'relation');
if isempty(m.term)
    return;
end
if ndi.v2.matchTerm(m.term, {'EMPTY:0000400', 'database linking'})
    link.kind = 'linked';
elseif ndi.v2.matchTerm(m.term, {'EMPTY:0000399', 'database ingestion'})
    link.kind = 'ingested';
else
    return;
end
entries = ndi.v2.entries(m.parameters);
for k = 1:numel(entries)
    e = entries{k};
    if ~isstruct(e) || isempty(e) || ~isfield(e, 'variable')
        continue;
    end
    [v, ~, form] = ndi.v2.entryValue(e);
    if ~strcmp(form, 'text')
        continue;
    end
    if ndi.v2.matchTerm(e(1).variable, {'NCIT:C47922', 'Pathname'})
        link.path = char(v);
    elseif ndi.v2.matchTerm(e(1).variable, {'EMPTY:0000401', 'software class'})
        link.software_class = char(v);
    end
end
end
