function name = recordRelation()
%RECORDRELATION The relation that files a record (a session, a study) under another.
%
%   NAME = ndi.v2.recordRelation() is the name of the directed relation by
%   which a session is in a study or a dataset, and a study in a dataset or a
%   larger study:
%     'included_in'  on a schema that binds it (did-schema
%                    V_eta_relation_inheritance_plan.md, 2026-10-20, a
%                    proposal built ahead of signature: `schema:isPartOf`,
%                    which passes nothing, so a study does not take its
%                    dataset's short name, version or licence; `part_of` is
%                    physical again);
%     'part_of'      otherwise (did-schema main, where the study plan of
%                    2026-09-30 widened part_of to records).
%   Every writer and reader of record membership asks this one function, so
%   the two schemas need no branch at each site. Read from the registry
%   ndi.v2.relationPasses keeps (ndi.setup.V2.schemaHasRelation's file).
%
%   See also ndi.v2.relationPasses, ndi.setup.V2.schemaHasRelation.

name = 'part_of';
if any(strcmp(ndi.v2.relationPasses().names, 'included_in'))
    name = 'included_in';
end
end
