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
%                     sample times -> sample_time.offsets (regular=false). Blank
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
    'name', 'migrated_visual_stimulus', 'datestamp', datestamp);
% storage_mode: body -> the grating value stream lives in the sampled_body.
manipBody.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'visual grating'), 'storage_mode', 'body');
manipBody.subject_interaction = struct( ...
    'method', struct('node', '', 'name', 'visual stimulus presentation'));
manipBody.subject_manipulation = struct();

% --- the sampled_body: sample-per-trial; onsets are the sample times ----------
datum = struct('kind', 'record', 'dtype', 'double', 'unit', '', ...
    'shape', [nTrials, 7]);
sampleTime = struct('regular', false, 'n', nTrials, 'offsets', onsets);
bodyDoc = struct();
bodyDoc.document_class = struct('class_name', 'sampled_body', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_body', 'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
bodyDoc.depends_on = struct('name', {'statement'}, 'value', {manipId});
bodyDoc.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_visual_stimulus_series', 'datestamp', datestamp);
bodyDoc.sampled_body = struct('datum', datum, 'sample_time', sampleTime, ...
    'summary', struct('value', struct(), 'time', struct()));
% `records` is returned for the caller to serialise into the body payload +
% content_hash (framework-side; kept out of the descriptor here).
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
