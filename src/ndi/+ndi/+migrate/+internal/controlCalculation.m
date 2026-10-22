function [calc, why] = controlCalculation(v1Body, presentationId, entityId, ...
        positions, sessionId)
%CONTROLCALCULATION A v1 control_stimulus_ids document as a did-schema #88
%   calculation.
%
%   [CALC, WHY] = ndi.migrate.internal.controlCalculation(V1BODY,
%       PRESENTATIONID, ENTITYID, POSITIONS, SESSIONID)
%
%   Decided by Jess Haley, 2026-10-21 [control record is a calculation]
%   (did-schema V_eta_stimulus_response_model_plan.md): a migrated v1
%   `control_stimulus_ids` document becomes a calculation whose input is the
%   stimulus presentation and whose value names which item is the control;
%   responses keep pointing at it in `input_id` ([control input told apart by
%   its document]). So:
%     base.id     the v1 control_stimulus_ids id, preserved (responses' input_id)
%     class       `calculation` with the `item` value kind
%     entity_id   what the presentation's manipulation is about (ENTITYID)
%     input_id    the presentation (PRESENTATIONID, the manipulation's id)
%     value.item  per v1 entry (one per trial, as tuning_response writes it),
%                 the 0-based position into the presentation's item_id of the
%                 control stimulus. A v1 entry is a TRIAL number (an index into
%                 presentation_order: B's control lists name trials 11 and 20
%                 of a 12-stimulus, 60-trial presentation, both showing
%                 stimulus 12), so POSITIONS is per trial: POSITIONS(entry).
%     method      the v1 control_stimulus_id_method: its `method` as the term,
%                 every other field a parameter
%     time        a stand-in swapped for the "during the session" marker, as
%                 the item manipulation's (the caller mints the reference)
%   The variable is the label 'control stimulus' (no registered term yet).
%
%   CALC is [] and WHY says why when there is no control to name: the v1
%   value is NaN or empty ('no control'), an entry falls outside the stimuli
%   list or is NaN among numbers ('unmappable'), or there is no subject or no
%   position map ('no subject' / 'no position map', e.g. a Hartley
%   enumeration).

calc = [];
why = '';
blk = struct();
if isfield(v1Body, 'control_stimulus_ids') && isstruct(v1Body.control_stimulus_ids)
    blk = v1Body.control_stimulus_ids;
end
ids = [];
if isfield(blk, 'control_stimulus_ids'); ids = blk.control_stimulus_ids; end
if iscell(ids)
    ids = cellfun(@(x) double(x), ids);
end
ids = double(ids(:)');
if isempty(ids) || all(isnan(ids))
    why = 'no control';
    return;
end
if isempty(entityId)
    why = 'no subject';
    return;
end
if isempty(positions)
    why = 'no position map';
    return;
end
if any(isnan(ids)) || any(ids < 1 | ids > numel(positions) | ids ~= floor(ids))
    why = 'unmappable';
    return;
end
value = struct('item', positions(ids));

csId = '';
if isfield(v1Body, 'base') && isfield(v1Body.base, 'id'); csId = char(v1Body.base.id); end
ds = '';
if isfield(v1Body, 'base') && isfield(v1Body.base, 'datestamp'); ds = char(v1Body.base.datestamp); end

% the method's labels are not registered terms (did2.convert turns the
% registry off while migrating; this builds outside it), so off before ANY
% did2.build call, parameters included
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
methodTerm = 'control stimulus identification';
params = [];
if isfield(blk, 'control_stimulus_id_method') && isstruct(blk.control_stimulus_id_method)
    m = blk.control_stimulus_id_method;
    entries = {};
    fn = fieldnames(m);
    for k = 1:numel(fn)
        v = m.(fn{k});
        if strcmp(fn{k}, 'method') && (ischar(v) || isstring(v)) && ~isempty(v)
            methodTerm = char(v);
            continue;
        end
        if ischar(v) || isstring(v)
            if isempty(v); continue; end
            entries{end+1} = did2.build.parameter(fn{k}, 'Text', char(v)); %#ok<AGROW>
        elseif (isnumeric(v) || islogical(v)) && ~isempty(v)
            entries{end+1} = did2.build.parameter(fn{k}, 'Value', double(v)); %#ok<AGROW>
        end
    end
    if ~isempty(entries)
        params = did2.build.list(entries{:});
    end
end

standIn = [csId '_time_reference_pending'];
args = {'ValueKind', 'item', 'Method', methodTerm, ...
    'TimeReferenceIds', {standIn}, 'InputIds', {presentationId}, ...
    'SessionId', sessionId, 'Id', csId, 'Validate', false};
if ~isempty(params)
    args = [args, {'MethodParameters', params}];
end
if ~isempty(ds)
    args = [args, {'CreationTimestamp', ds}];
end
calc = did2.build.statement('calculation', entityId, 'control stimulus', value, args{:});
keep = arrayfun(@(d) ~strcmp(char(d.name), 'time_reference_id'), calc.depends_on);
calc.depends_on = calc.depends_on(keep);
e = struct();
f = fieldnames(calc.depends_on);
for i = 1:numel(f); e.(f{i}) = ''; end
e.name = did2.convert.mintSessionDuring('marker');
if isfield(e, 'document_id'); e.document_id = csId; else; e.value = csId; end
calc.depends_on(end+1) = e;
end
