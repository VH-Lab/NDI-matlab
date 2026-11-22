function ids = otherSystemsAnchorIds(statements, sysIds)
%OTHERSYSTEMSANCHORIDS The time references another acquisition system's statements name.
%
%   IDS = otherSystemsAnchorIds(STATEMENTS, SYSIDS) is a cellstr of the
%   `time_reference_id` targets of each of STATEMENTS (ndi.documents, full or
%   light) that names an `acquisition_system_id` none of which is in SYSIDS
%   (the ids of the reader's acquisition systems).
%
%   WHY. An epoch entity is shared by every system that recorded it, and
%   each system's v1 archive stated its own clocks and t0_t1 for it, which
%   DID-matlab writes as relative_time_references onto that one entity
%   (did2.convert.resolveEpochProbemap, [clock only on the time reference]).
%   A reader finds its own references through its recordings, which name
%   them (private/archiveOf: "the recordings' anchors in the order they name
%   them, then the rest"). A stimulus log owned by its presentation ([stimulus
%   log owned by its presentation], Jess Haley, 2026-11-19) has no recording
%   on the stimulus system, so nothing names that system's references; they
%   are told apart from the others' by elimination: a reference another
%   system's statement names is that system's. In Soph the stimulus system's
%   t0_t1 differs from the Intan system's for all 174 of its 175 epochs that
%   the Intan system also recorded (read from the Soph corpus's v1
%   documents, 2026-11-19), so reading the first reference onto the epoch
%   could read the wrong extent.
%
%   See also ndi.vintage.ingestedArchive, ndi.vintage.ingestedArchives.

ids = {};
for k = 1:numel(statements)
    sys = ndi.vintage.edgeTargets(statements{k}, 'acquisition_system_id');
    sys = sys(~cellfun(@isempty, sys));
    if isempty(sys) || any(ismember(sys, sysIds))
        continue;
    end
    ids = [ids, ndi.vintage.edgeTargets(statements{k}, 'time_reference_id')]; %#ok<AGROW>
end
ids = unique(ids(~cellfun(@isempty, ids)));
end
