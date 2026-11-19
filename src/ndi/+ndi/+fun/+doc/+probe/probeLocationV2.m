function docs = probeLocationV2(S, probeId, ontologyName, name)
%PROBELOCATIONV2 The v2 record of a probe's location, for a v2 database.
%
%   DOCS = ndi.fun.doc.probe.probeLocationV2(S, PROBEID, ONTOLOGYNAME, NAME)
%   returns {observation, time reference} as ndi.document objects for the
%   session S (whose database is v2, ndi.session/writesV2): the shape
%   DID-matlab's +migrators_j/probe_location.m gives a v1 `probe_location`
%   document (confirmed by the team, did-schema
%   did_v2_go_forward_class_audit.md [confirm sheet 2026-08-17]):
%
%     an `observation` with value kind `term` about the probe (`entity_id`
%       PROBEID), variable NCIT:C13717 "Anatomic Site", value the location
%       term (node ONTOLOGYNAME, name NAME, as the term registry writes it,
%       ndi.setup.V2.registeredTerm), pointing at
%     a `relative_time_reference` "during the session" (referent the session,
%       relation intervalDuring), as the migrator's session anchor.
%
%   did2.build refuses a location term the term registry does not hold
%   (tenet T19).
%
%   Jess Haley's decisions of 2026-11-03 [writers are given the session] and
%   [v2 line reads and writes both] (did-schema
%   did_v2_go_forward_class_audit.md): a tool learns the version from the
%   session's database.
%
%   See also ndi.fun.doc.probe.probeLocations4probes, ndi.session/writesV2.

arguments
    S (1,1) ndi.session
    probeId {mustBeTextScalar, mustBeNonzeroLengthText}
    ontologyName {mustBeTextScalar, mustBeNonzeroLengthText}
    name {mustBeTextScalar} = ''
end

sid = S.id();
anchor = did2.build.relativeTimeReference(sid, 'Relation', 'intervalDuring', ...
    'SessionId', sid);
obs = did2.build.statement('observation', char(probeId), ...
    ndi.setup.V2.registeredTerm('NCIT:C13717', 'Anatomic Site'), ...
    ndi.setup.V2.registeredTerm(char(ontologyName), char(name)), ...
    'TimeReferenceIds', {anchor.base.id}, 'SessionId', sid, 'ValueKind', 'term');
docs = cellfun(@(x) ndi.document(x), {obs, anchor}, 'UniformOutput', false);
end
