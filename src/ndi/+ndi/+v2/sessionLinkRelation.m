function doc = sessionLinkRelation(entityId, parentId, linked, softwareClass, pathname, datasetSessionId)
%SESSIONLINKRELATION The relation that puts a session in a V2 dataset, with HOW it joined.
%
%   DOC = ndi.v2.sessionLinkRelation(ENTITYID, PARENTID, LINKED, SOFTWARECLASS,
%   PATHNAME, DATASETSESSIONID) builds (did2.build.directedRelation) the one
%   session -> dataset `included_in` relation whose method records how the
%   session is in the dataset (did-schema V_eta_go_forward_class_audit.md,
%   Jess Haley 2026-10-29 [linked session link on a direct dataset relation],
%   [linked session link details], [linked session pathname]):
%
%     LINKED true   method term "database linking" (EMPTY:0000400); its
%                   parameters "software class" (EMPTY:0000401) = SOFTWARECLASS
%                   (the class that opens the session, e.g. ndi.session.dir)
%                   and Pathname (NCIT:C47922) = PATHNAME, the session's folder
%                   as ndi.v2.linkPath writes it (relative to the dataset's
%                   folder, with '/', when inside it; absolute otherwise)
%     LINKED false  method term "database ingestion" (EMPTY:0000399); its
%                   parameter "software class" = SOFTWARECLASS
%
%   ENTITYID is the session's `session` entity document; PARENTID the
%   dataset's `dataset` entity document (or, where the dataset holds none, the
%   study the session is filed under). The relation is written in the
%   dataset's database, with session id DATASETSESSIONID. It replaces the
%   withdrawn `linked_session` document ([linked_session withdrawn],
%   V_eta_linked_session_plan.md). Converting a session between linked and
%   ingested replaces this relation with a new one; it is never edited.
%   An empty SOFTWARECLASS or PATHNAME writes no such parameter.
%
%   See also ndi.v2.sessionLinkOf, ndi.v2.linkPath, ndi.v2.datasetSessions.

arguments
    entityId (1,:) char {mustBeNonzeroLengthText}
    parentId (1,:) char {mustBeNonzeroLengthText}
    linked (1,1) logical
    softwareClass (1,:) char
    pathname (1,:) char
    datasetSessionId (1,:) char {mustBeNonzeroLengthText}
end

params = {};
if ~isempty(softwareClass)
    params{end+1} = did2.build.parameter( ...
        ndi.setup.V2.registeredTerm('EMPTY:0000401', 'software class'), 'Text', softwareClass);
end
if linked
    method = ndi.setup.V2.registeredTerm('EMPTY:0000400', 'database linking');
    if ~isempty(pathname)
        params{end+1} = did2.build.parameter( ...
            ndi.setup.V2.registeredTerm('NCIT:C47922', 'Pathname'), 'Text', pathname);
    end
else
    method = ndi.setup.V2.registeredTerm('EMPTY:0000399', 'database ingestion');
end
opts = {'Method', method, 'SessionId', datasetSessionId};
if ~isempty(params)
    opts = [opts, {'MethodParameters', did2.build.list(params{:})}];
end
doc = did2.build.directedRelation(entityId, parentId, ...
    ndi.v2.vocabTerm('relation', 'included_in'), opts{:});
end
