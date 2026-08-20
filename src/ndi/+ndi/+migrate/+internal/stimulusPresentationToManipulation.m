function [manipBody, bodyDoc, records] = stimulusPresentationToManipulation(v1Body, resolver, targetVersion)
%STIMULUSPRESENTATIONTOMANIPULATION Assemble a body-backed visual_grating_manipulation
%   (+ its sampled_body) from a legacy stimulus_presentation, using the recording
%   graph. The subject (animal) and the trial series are only available with the whole
%   body set, so the per-document converter defers this to the second pass.
%
%   A stimulus_presentation is an ordered list of stimulus TRIALS (presentation_order
%   indexes stimuli[]; presentation_time gives per-trial onset/offset). It becomes ONE
%   visual_grating_manipulation on the animal, its value BODY-BACKED as a sample-per
%   -trial series:
%     - subject       resolver.subjectsForPresentation(presentationId) -- the animal,
%                     via the response link (stimulus_response -> element -> subject).
%     - visual_grating_manipulation   storage_mode: body; the statement head.
%     - sampled_body  one record per trial: the grating value
%                     (gratingValueFromParameters) + duration; the trial ONSETS are the
%                     sample times -> axes(1).values (regular=false). Blank
%                     (is_blank) trials are kept as rows. The record matrix is returned
%                     separately as `records` for the caller to serialise into the body
%                     payload (content_hash).
%
%   Returns [] for all outputs when no animal responded (nothing to place the
%   manipulation on -- the caller leaves the presentation as-is).
%
%   See also: ndi.migrate.internal.bodyResolver (subjectsForPresentation),
%   ndi.migrate.internal.gratingValueFromParameters, ndi.migrate.internal.stimulusBathToBath.

arguments
    v1Body   (1,1) struct
    resolver (1,1) struct
    targetVersion (1,:) char = 'V_eta'
end

manipBody = []; bodyDoc = []; records = [];

presentationId = baseField(v1Body, 'id', '');
sessionId      = baseField(v1Body, 'session_id', '');
datestamp      = baseField(v1Body, 'datestamp', '');

animals = resolver.subjectsForPresentation(presentationId);
if isempty(animals)
    return;   % nothing responded -> cannot place the manipulation; leave as-is
end
animalId = animals{1};

% --- read the trial series (order + per-trial time + per-stim parameters) -----
block = struct();
if isfield(v1Body, 'stimulus_presentation') && isstruct(v1Body.stimulus_presentation)
    block = v1Body.stimulus_presentation;
end
order = [];
if isfield(block, 'presentation_order'); order = double(block.presentation_order(:)'); end
times = struct([]);
if isfield(block, 'presentation_time') && isstruct(block.presentation_time)
    times = block.presentation_time;
end
stimuli = struct([]);
if isfield(block, 'stimuli') && isstruct(block.stimuli); stimuli = block.stimuli; end

nTrials = numel(order);
onsets   = zeros(1, nTrials);
gratings = cell(1, nTrials);
durations = zeros(1, nTrials);
for k = 1:nTrials
    stimIdx = order(k);
    onsets(k)    = trialField(times, k, 'onset');
    durations(k) = trialField(times, k, 'offset') - onsets(k);
    params = stimParameters(stimuli, stimIdx);
    gratings{k} = ndi.migrate.internal.gratingValueFromParameters(params);
end
% record matrix: [angle sf tf contrast size is_blank duration] per trial
records = zeros(nTrials, 7);
for k = 1:nTrials
    g = gratings{k};
    records(k, :) = [g.angle, g.spatial_frequency, g.temporal_frequency, ...
        g.contrast, g.size, double(g.is_blank), durations(k)];
end

% --- the manipulation statement (body-backed, on the animal) ------------------
manipId = presentationId;   % preserve the source id so inbound refs resolve
manipBody = struct();
manipBody.document_class = struct('class_name', 'visual_grating_manipulation', ...
    'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_manipulation', 'class_version', '1.0.0'), ...
        struct('class_name', 'visual_grating',       'class_version', '1.0.0')], ...
    'schema_version', targetVersion);
manipBody.depends_on = struct('name', {'subject_id'}, 'value', {animalId});
manipBody.base = struct('id', manipId, 'session_id', sessionId, ...
    'name', 'migrated_visual_stimulus', 'creation_timestamp', datestamp);
% storage_mode: body -> the grating value stream lives in the sampled_body.
% `datum_type` LIVES ON THE STATEMENT NOW (DID-schema TEAM-SIGN-OFF [data_body]
% 2026-08-14, sec.5: "datum collapses to datum_type and moves TO THE STATEMENT").
% The statement says what the values ARE; the body says how the bytes lay out.
% `records` is built here as a double matrix, so the normalised type is float64
% and the source spelling 'double' is kept beside it -- the same pair
% DID-matlab's private/jDatumType.m produces for every migrator on that side.
manipBody.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'visual grating'), ...
    'datum_type', 'float64', 'source_datum_type', 'double', ...
    'storage_mode', 'body');
manipBody.subject_interaction = struct( ...
    'method', struct('node', '', 'name', 'visual stimulus presentation'));
manipBody.subject_manipulation = struct();

% --- the sampled_body: sample-per-trial; onsets are the sample times ----------
% REWRITTEN FOR THE SIGNED AXIS ENTRY. This wrote three blocks that the V_eta
% `sampled_body` no longer declares -- `datum`, `summary` and (now) `sample_time`
% -- and the first two were an ACTIVE BREAK rather than a tidy-up: `datum` and
% `summary` were removed from the schema on 2026-08-14, so every document this
% pass emitted would have failed `undeclaredField` and quarantined. The quick
% migrator gate does not run the second pass, so only a corpus run would have
% surfaced it.
%
%   datum.dtype  -> subject_statement.datum_type (above)
%   datum.shape  -> the axes below, which is what `[axes.n] in array order` means
%   datum.unit   -> dropped; it was '' at every writer
%   summary      -> DROPPED outright (#68, signed sec.9: empty at every writer,
%                   read by nothing -- the vacuous-composite shape #38 catches)
%   sample_time  -> axes(1); writing the cadence into both would store one fact
%                   twice, the #69 shape this step removes
%
% TWO AXES, IN ARRAY ORDER, BECAUSE `records` IS [nTrials x 7] AND THE SCHEMA
% READS THE LIST POSITIONALLY -- `axes[k] IS array dimension k`. A one-entry list
% would assert that dimension 1 is whatever it names; there is no partial mode.
% (pyraview shipped exactly that defect on 2026-08-15 and had to be corrected.)
%
% AND THE SECOND AXIS IS A GAIN, not just bookkeeping: the seven columns were
% documented ONLY in a code comment above the `records` assembly, so a reader of
% the migrated data had no way to know which column was contrast. `labels` is an
% ontology_term ARRAY for exactly this -- naming enumerated positions on an axis.
trialAxis = axisEntry(struct('node', '', 'name', 'time'), nTrials);
trialAxis.regular     = false;      % trial onsets are irregular by construction
trialAxis.source_unit = 's';
% Assigned separately, NOT through struct(...): a non-scalar value passed to
% struct() distributes into a struct ARRAY instead of setting one field.
trialAxis.values = struct('values', {onsets}, 'source_values', {onsets});

paramAxis = axisEntry(struct('node', '', 'name', 'stimulus parameter'), 7);
paramAxis.labels = [ ...
    struct('node', '', 'name', 'angle'), ...
    struct('node', '', 'name', 'spatial frequency'), ...
    struct('node', '', 'name', 'temporal frequency'), ...
    struct('node', '', 'name', 'contrast'), ...
    struct('node', '', 'name', 'size'), ...
    struct('node', '', 'name', 'is blank'), ...
    struct('node', '', 'name', 'duration')];

bodyDoc = struct();
bodyDoc.document_class = struct('class_name', 'sampled_body', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_body', 'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
bodyDoc.depends_on = struct('name', {'statement'}, 'value', {manipId});
bodyDoc.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_visual_stimulus_series', 'creation_timestamp', datestamp);
bodyDoc.sampled_body = struct();
% In its own statement for the struct()-distribution reason given above.
bodyDoc.sampled_body.axes = [trialAxis, paramAxis];
% `records` is returned for the caller to serialise into the body payload +
% content_hash (framework-side; kept out of the descriptor here).
end

function ax = axisEntry(variable, n)
%AXISENTRY One signed axis entry, every field present, in a FIXED order.
%   The DID-schema signed entry (TEAM-SIGN-OFF [data_body] 2026-08-14 +
%   AMENDMENT 1) declares ten sub-fields. Every one is set here, to the schema's
%   own blank where the caller has nothing to say, for two reasons:
%
%   (1) `axes` is an ARRAY, and MATLAB concatenates struct arrays only when the
%       operands share a field set AND its order -- so `[trialAxis, paramAxis]`
%       would throw whenever one entry omits a field the other sets. That
%       failure appears only on the multi-axis path, which is the path least
%       likely to be fixtured.
%   (2) A present-but-blank field is indistinguishable from an absent one to the
%       validator, so nothing is asserted that was not measured.
%
%   `variable` and `n` are the two mustBeNonEmpty sub-fields and are therefore
%   positional -- an axis that cannot name itself or state its extent is not an
%   axis.
%
%   This is the NDI-side twin of DID-matlab's
%   +did2/+convert/+migrators_j/private/jAxis.m. It is duplicated rather than
%   shared because `private/` is reachable only from its own parent folder and
%   the two repositories do not share a path; if a third writer appears, promote
%   it rather than copy it a second time.
ax = struct();          % assigned one at a time -- struct(...) distributes
ax.variable    = variable;
ax.unit        = struct('node', '', 'name', '');
ax.source_unit = '';
ax.approximate = false;
ax.n           = n;
ax.regular     = false;
ax.origin      = struct();
ax.spacing     = struct();
ax.values      = struct();
ax.labels      = struct('node', '', 'name', '');
end

% ===================== helpers ============================================

function v = trialField(times, k, name)
v = 0;
if isstruct(times) && numel(times) >= k && isfield(times(k), name) ...
        && isnumeric(times(k).(name)) && ~isempty(times(k).(name))
    v = double(times(k).(name)(1));
end
end

function params = stimParameters(stimuli, stimIdx)
params = struct();
if isstruct(stimuli) && stimIdx >= 1 && numel(stimuli) >= stimIdx ...
        && isfield(stimuli(stimIdx), 'parameters') && isstruct(stimuli(stimIdx).parameters)
    params = stimuli(stimIdx).parameters;
end
end

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name) ...
        && ~isempty(body.base.(name))
    v = body.base.(name);
end
end
