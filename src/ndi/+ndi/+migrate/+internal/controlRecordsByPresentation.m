function [byPresentation, report] = controlRecordsByPresentation(v1Bodies, handedOnIds)
%CONTROLRECORDSBYPRESENTATION The v1 control_stimulus_ids documents, read from
%   the ORIGINAL v1 bodies and grouped by the presentation each one names.
%
%   [BYPRESENTATION, REPORT] = ndi.migrate.internal.controlRecordsByPresentation( ...
%       V1BODIES, HANDEDONIDS)
%
%   Decided by Jess Haley, 2026-10-27 [second pass reads control stimuli from
%   v1] (did-schema V_eta_go_forward_class_audit.md): NDI's second pass reads
%   a v1 control_stimulus_ids from the original v1 document, not from pass 1's
%   output, so DID-matlab can move the class to its raw-v1 path (the class
%   joins `rawV1Classes`) without this pass depending on what pass 1 does to
%   the body. The record is read exactly as NDI's writer wrote it
%   (+app/+stimulus/tuning_response.m): `depends_on` entry
%   `stimulus_presentation_id` with key `value`, the `control_stimulus_ids`
%   block, the `app` block.
%
%   V1BODIES     the v1 bodies the migration read (a cell of structs, or of
%                JSON text, as ndi.migrate.local reads them).
%   HANDEDONIDS  the base.id of every document pass 1 handed on (its
%                `migrated` set, any class). A v1 record pass 1 did not hand on
%                (it quarantined it) is NOT folded: folding it would mint a
%                calculation beside the quarantined original under one id.
%                Omit it (or pass {}) to take every v1 record.
%
%   BYPRESENTATION  containers.Map: presentation id -> cell of v1 record
%                   structs, in body order.
%   REPORT          denominators first:
%     .bodies_inspected          numel(V1BODIES)
%     .bodies_unreadable         entries that are not one struct (or JSON of one)
%     .control_records_v1        v1 control_stimulus_ids bodies seen
%     .control_not_handed_on     of those, absent from HANDEDONIDS (not folded)
%     .control_records_read      of those, handed on (the fold's denominator)
%     .control_no_presentation   of the read ones, naming no presentation
%
%   See also ndi.migrate.local (resolveStimulusPresentations),
%   ndi.migrate.internal.stimulusPresentationToItem.

arguments
    v1Bodies cell
    handedOnIds = []
end

report = struct( ...
    'bodies_inspected',        numel(v1Bodies), ...
    'bodies_unreadable',       0, ...
    'control_records_v1',      0, ...
    'control_not_handed_on',   0, ...
    'control_records_read',    0, ...
    'control_no_presentation', 0);
byPresentation = containers.Map('KeyType', 'char', 'ValueType', 'any');

checkHandedOn = ~isempty(handedOnIds);
if checkHandedOn
    handed = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    handedOnIds = cellstr(handedOnIds);
    for k = 1:numel(handedOnIds)
        if ~isempty(handedOnIds{k})
            handed(handedOnIds{k}) = true;
        end
    end
end

for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            b = [];
        end
    end
    if ~isstruct(b) || ~isscalar(b)
        report.bodies_unreadable = report.bodies_unreadable + 1;
        continue;
    end
    if ~strcmp(classNameOf(b), 'control_stimulus_ids')
        continue;
    end
    report.control_records_v1 = report.control_records_v1 + 1;
    if checkHandedOn
        id = '';
        if isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
            id = char(b.base.id);
        end
        if isempty(id) || ~isKey(handed, id)
            report.control_not_handed_on = report.control_not_handed_on + 1;
            continue;
        end
    end
    report.control_records_read = report.control_records_read + 1;
    presId = ndi.migrate.internal.etaShape.edge(b, 'stimulus_presentation_id');
    if isempty(presId)
        report.control_no_presentation = report.control_no_presentation + 1;
        continue;
    end
    held = {};
    if isKey(byPresentation, presId)
        held = byPresentation(presId);
    end
    held{end+1} = b; %#ok<AGROW>
    byPresentation(presId) = held;
end
end

function c = classNameOf(b)
c = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    c = char(b.document_class.class_name);
end
end
