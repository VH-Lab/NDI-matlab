function docs = sessionCohort(cohortId, sessionId, memberIds, creationTimestamp)
%SESSIONCOHORT A session's cohort: one group entity and a `member_of` edge per
%   animal.
%
%   DOCS = ndi.migrate.internal.sessionCohort(COHORTID, SESSIONID, MEMBERIDS,
%   TIMESTAMP) returns {cohort, member_of_1, ..., member_of_N}:
%
%     cohort     an `entity` of type `group`, base.id COHORTID, local
%                identifier 'session cohort <SESSIONID>' (a group requires a
%                local_identifier: binding_registry_meta entity_type_bindings)
%     member_of  a directed_relation per member, child = the animal, parent =
%                the cohort (RO:0002350, completed by did2.build from the bound
%                relation set). Unordered: a cohort leaves `order` empty.
%
%   THE DECISION (Jess Haley, 2026-10-21; V_eta_stimulus_model_plan.md, "Who
%   received a presentation", decision 2, not a TEAM-SIGN-OFF line): several
%   animals in one session get ONE manipulation of the session's cohort,
%   marked `distributive`, never N copies. The cohort is a STANDING group --
%   the animals recorded together in that session -- minted once per session
%   and reused by every presentation in it. This builds exactly that and
%   nothing more. In particular it writes no term assertion naming the
%   group's finer kind ("cohort"): that is the proposed, unsigned T20.
%
%   Built with did2.build (Validate false; the caller's v1_to_v2 fold
%   validates), so the shape is the schema's, as the V2 Haley import builds
%   its cohorts and as ndi.unittest.setup.V2.TestCohortStimulus reads them.

arguments
    cohortId (1,:) char
    sessionId (1,:) char
    memberIds cell
    creationTimestamp (1,:) char
end

restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
common = {'SessionId', sessionId, 'CreationTimestamp', creationTimestamp, ...
    'Validate', false};
cohort = did2.build.document('entity', struct( ...
    'type', did2.build.term('', 'group'), ...
    'name', 'session cohort', ...
    'local_identifier', ['session cohort ' sessionId]), ...
    'Id', cohortId, common{:});
docs = {cohort};
for k = 1:numel(memberIds)
    docs{end+1} = did2.build.directedRelation(char(memberIds{k}), cohortId, ...
        'member_of', common{:}); %#ok<AGROW>
end
end
