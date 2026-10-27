function [anchors, report] = presentationEpochAnchors(manipulations, epochInfo)
%PRESENTATIONEPOCHANCHORS The epoch anchors of the stimulus presentations'
%   manipulations, handed to ndi.migrate.internal.epochAnchorFold.
%
%   [ANCHORS, REPORT] = ndi.migrate.internal.presentationEpochAnchors( ...
%       MANIPULATIONS, EPOCHINFO)
%
%   Decided by Jess Haley, 2026-10-27 [presentation anchored to its epoch]
%   (did-schema V_eta_go_forward_class_audit.md, option a, no new field): a
%   v1 `stimulus_presentation`'s V2 `manipulation` anchors its time reference
%   to the entity of the epoch the presentation was in.
%
%   The stimulus pass (ndi.migrate.local, resolveStimulusPresentations) runs
%   before did2.convert.epochMint mints the epoch entities, so each
%   manipulation is first anchored "during the session" by
%   did2.convert.mintSessionDuring (one `relative_time_reference` per
%   manipulation, on its `time_reference_id` edge). This function names each
%   such reference with the presentation's (session, epoch string, clock), in
%   the shape the bath anchors already use, and epochAnchorFold re-points it
%   at the epoch entity minted for that (session, epoch string) PAIR, id
%   preserved, after epochMint. A reference the fold refuses stays on its
%   session; the caller counts those (ANCHORS_LEFT_ON_SESSION below).
%
%   MANIPULATIONS  cell of manipulation bodies AFTER mintSessionDuring.
%   EPOCHINFO      struct array, one per manipulation, fields session_id,
%                  epoch_string (v1 `epochid.epochid`), epoch_clock.
%
%   ANCHORS  struct array {anchor_id, session_id, epoch_string, epoch_clock}
%            (the BATHANCHORS shape epochAnchorFold reads).
%   REPORT   denominators first:
%     .manipulations_inspected  numel(MANIPULATIONS)
%     .anchors_handed_over      references named here
%     .no_epoch_string          the presentation names no epoch
%     .no_session_reference     mintSessionDuring gave it no reference
%     .anchors_refolded         filled by the caller after the fold
%     .anchors_left_on_session  filled by the caller after the fold
%
%   See also ndi.migrate.internal.epochAnchorFold, did2.convert.epochMint.

arguments
    manipulations cell
    epochInfo struct
end

report = struct( ...
    'manipulations_inspected', numel(manipulations), ...
    'anchors_handed_over',     0, ...
    'no_epoch_string',         0, ...
    'no_session_reference',    0, ...
    'anchors_refolded',        0, ...
    'anchors_left_on_session', 0);
anchors = struct('anchor_id', {}, 'session_id', {}, 'epoch_string', {}, ...
    'epoch_clock', {});

if numel(epochInfo) ~= numel(manipulations)
    error('NDI:migrate:presentationEpochAnchors:size', ...
        '%d manipulation(s) but %d epoch row(s).', numel(manipulations), ...
        numel(epochInfo));
end

for k = 1:numel(manipulations)
    info = epochInfo(k);
    epochString = charField(info, 'epoch_string');
    if isempty(epochString)
        report.no_epoch_string = report.no_epoch_string + 1;
        continue;
    end
    refId = ndi.migrate.internal.etaShape.edge(manipulations{k}, 'time_reference_id');
    if isempty(refId)
        report.no_session_reference = report.no_session_reference + 1;
        continue;
    end
    anchors(end+1) = struct('anchor_id', char(refId), ...
        'session_id', charField(info, 'session_id'), ...
        'epoch_string', epochString, ...
        'epoch_clock', charField(info, 'epoch_clock')); %#ok<AGROW>
end
report.anchors_handed_over = numel(anchors);
end

function v = charField(s, name)
v = '';
if isfield(s, name) && ~isempty(s.(name))
    v = char(s.(name));
end
end
