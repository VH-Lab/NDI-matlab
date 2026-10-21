function [manipBody, methodBodies, report] = ...
        stimulusPresentationToItem(v1Body, resolver, sequence, options)
%STIMULUSPRESENTATIONTOITEM Decompose one legacy stimulus_presentation into the
%   did-schema #88 stimulus shape: N deduplicated standalone `method`
%   documents (one per distinct stimulus, given as a recipe) plus ONE
%   `manipulation` (value kind `item`) whose `item` value is the playlist into them.
%
%   [MANIP, METHODS, REPORT] = stimulusPresentationToItem(V1BODY, RESOLVER)
%   [...] = stimulusPresentationToItem(V1BODY, RESOLVER, SEQUENCE)
%   [...] = stimulusPresentationToItem(..., 'CohortIdFor', @(sessionId) id)
%
%   THE SHAPE (did-schema PR #88; all of it built with did2.build, so it is
%   read from the schema in use and never spelled here):
%     V_eta_method_plan.md (TEAM-SIGN-OFF [method], 2026-10-21)
%         "recipe stimuli are method documents referenced by item;
%          visual_grating and spatial_frequency deleted"
%     V_eta_study_plan.md: `item` replaces `timed_sequence`.
%     V_eta_entity_composition_plan.md sec. 1: a statement is a direction
%         class plus ONE value-kind mixin, so the manipulation is a
%         `manipulation` listing `item`: did2.build.statement('manipulation',
%         ..., 'ValueKind', 'item').
%
%   WHAT IT EMITS, per input stimulus_presentation
%     methodBodies  one `method` document per DISTINCT stimulus
%                   ({term, parameters}, ndi.migrate.internal.stimulusRecipe /
%                   stimulusMethod), deduplicated by the recipe itself. New
%                   ids: nothing in v1 references a single stimulus. Empty on
%                   the SEQUENCE path (the shared Hartley basis is minted once
%                   by the caller).
%     manipBody     ONE manipulation (value kind item), base.id = THE V1 PRESENTATION id,
%                   so every inbound `stimulus_presentation_id` keeps
%                   resolving (494 inbound edges onto 11 ids on 20211116).
%                     entity_id      the animal; or the session's COHORT
%                                    (see SEVERAL ANIMALS)
%                     instrument_id  the stimulator, v1 `stimulus_element_id`
%                                    (T7), omitted when absent
%                     item_id        the distinct method documents, in order
%                     item.value.item         the v1 playlist remapped onto
%                                             the distinct set, 0-BASED (T14)
%                     item.value.offset       each trial's end, when every
%                                             trial is timed
%                     item.value.control_item the blank's 0-based position,
%                                             when exactly one distinct blank
%                     keys           one `time` key (the trial onsets), only
%                                    when every trial is timed
%                     method         inline {term 'visual stimulation'}: how
%                                    the sequence was delivered (the plan's
%                                    own example); what each stimulus was is
%                                    on the documents the playlist names
%                     statement.distributive  true on a cohort manipulation
%                   Its time reference is NOT minted here: the edge is
%                   replaced by the did2.convert.mintSessionDuring marker,
%                   and ndi.migrate.local mints "during the session" for it
%                   (the lightsheet decision, Jess 2026-10-14, option A). The
%                   epoch anchor the plan prefers needs a clocktype that lives
%                   in presentation_time.bin, which a batch pass does not open.
%
%   THE STIMULUS KINDS. Decided by Jess Haley, 2026-10-21 [non-grating
%   stimuli as methods] (V_eta_method_plan.md): a visual stimulus that is not
%   a grating migrates the same way as a grating -- one `method` per distinct
%   stimulus, its term naming the kind, every v1 parameter an entry. The kind
%   is the NewStim class, recognised from the parameter field set its verify
%   function fixes (newStimKind below). A presentation folds when EVERY
%   stimulus is one of the kinds ndi.migrate.internal.stimulusRecipe
%   describes: a periodicstim grating (imageType 1 or 2), a blank, a
%   periodicstim uniform field (imageType 0, flashed bars) or other imageType,
%   a stochasticgridstim (dense noise), a blinkingstim (sparse noise) or a
%   shapemoviestim (shape movie). It is REFUSED and left as v1 when any
%   stimulus is a hartleystim generator with no hartley_calc enumeration
%   supplied (that path is SEQUENCE below), matches more than one class, or
%   matches none. REPORT.stimulus_kinds has the per-kind counts;
%   REPORT.non_grating_stimuli counts the stimuli that are neither a grating
%   nor a blank (folded or not).
%
%   WHO RECEIVED IT (stimulus plan, decisions of 2026-10-21), strongest first:
%   a stimulus response naming the presentation, then the elements recorded
%   in the presentation's own session-epoch, then the animal its stimulator
%   element names (the stimulator route never leaves the session). Fork 2
%   (a sibling session's epoch) stays disarmed.
%
%   SEVERAL ANIMALS (decision 2): when the response or epoch route gives
%   several animals, the manipulation is ONE manipulation of the session's
%   cohort, `distributive` true -- never N copies. The caller owns the cohort
%   (a standing group, minted once per session and reused): pass
%   'CohortIdFor', a function of the session id returning the cohort's id.
%   REPORT.animals lists the animals, for the caller's `member_of` edges.
%   Without 'CohortIdFor' such a presentation is refused and counted.
%   STIMULATOR LINKS THAT LEAD TO DIFFERENT ANIMALS ARE REFUSED (decision 4):
%   conflicting records are not a shared event.
%
%   NO SUBJECT (decided by Jess Haley, 2026-10-21, "a"): when no response
%   names the presentation, its session-epoch records no element, and the
%   stimulator names no animal, the presentation is NOT left as v1. MANIP is
%   then a STANDALONE `item` document -- the same ordered, timed list of
%   stimuli the manipulation would have referenced, base.id = the
%   presentation id -- with no manipulation, no entity and no instrument.
%   REPORT.standalone is true and REPORT.no_subject_reason says why no
%   subject resolved. A presentation whose epoch DOES record elements that
%   resolve to no subject is still refused (its reason says so), as is one
%   the grating guard refuses.
%
%   SEQUENCE (optional) supplies an enumeration the presentation lacks:
%     .item_ids     cell of ALREADY-MINTED method ids
%     .order        [1 x nFrames] 1-based index into item_ids, per frame
%     .frame_times  [1 x nFrames] frame onsets, seconds (optional)
%     .duration     seconds per frame (optional; gives the offsets)
%   ndi.migrate.internal.hartleyBasisGratings builds it from the hartley_calc
%   documents that reference the presentation.
%
%   TIMING. The v1 writer puts the trial times in presentation_time.bin
%   (+ndi/+app/+stimulus/decoder.m:132-134), which this pass does not open;
%   the deprecated inline `presentation_time` is read when EVERY trial has an
%   onset and an offset, and otherwise no key is written at all ("nobody
%   looked" is not "it happened at t=0").
%
%   Returns [] for MANIP and a REPORT carrying `reason` when nothing can be
%   assembled; the caller leaves the presentation as v1.
%
%   See also ndi.migrate.internal.gratingRecipe,
%   ndi.migrate.internal.stimulusMethod,
%   ndi.migrate.internal.hartleyBasisGratings,
%   ndi.migrate.internal.bodyResolver.

arguments
    v1Body   (1,1) struct
    resolver (1,1) struct
    sequence = []
    options.CohortIdFor = []
end

manipBody = []; methodBodies = {};
report = newReport();

presentationId = baseField(v1Body, 'id', '');
sessionId      = ndi.v2.sessionIdOf(v1Body);
datestamp      = baseField(v1Body, 'datestamp', '');
report.epoch_id = epochIdOf(v1Body);
if isempty(presentationId) || isempty(sessionId) || isempty(datestamp)
    report.reason = 'base id / session_id / datestamp incomplete';
    return;
end

% THE PER-KIND BREAKDOWN, taken before anything can refuse, so a refused
% presentation still reports what it holds.
earlyBlock = presentationBlock(v1Body);
earlyStimuli = stimulusArray(earlyBlock);
stimulusKinds = cell(1, numel(earlyStimuli));
for i = 1:numel(earlyStimuli)
    stimulusKinds{i} = newStimKind(stimParameters(earlyStimuli, i));
    report.stimulus_kinds.(stimulusKinds{i}) = ...
        report.stimulus_kinds.(stimulusKinds{i}) + 1;
end

% ---- who received it -------------------------------------------------------
animals = resolver.subjectsForPresentation(presentationId);
report.subjects_resolved = numel(animals);
report.animal_source = 'response';
if isempty(animals)
    scoped = resolver.subjectsViaEpochScoped(presentationId);
    if ~isempty(scoped)
        animals = scoped;
        report.animal_source = 'epoch';
    else
        report.animal_source = 'none';
        nEl = resolver.epochElementCountScoped(presentationId);
        if nEl > 0
            report.reason = sprintf(['no responding animal; the epoch''s %d ' ...
                'recorded element(s) resolve to no subject'], nEl);
            return;
        end
        viaStimulator = resolver.subjectsViaStimulator(presentationId);
        report.stimulator_subjects = numel(viaStimulator);
        if numel(viaStimulator) == 1
            animals = viaStimulator;
            report.animal_source = 'stimulator';
        elseif numel(viaStimulator) > 1
            % Decision 4: different animals by different stimulator links
            % are conflicting records, not a shared event.
            report.several_animals = numel(viaStimulator);
            report.reason = sprintf(['several animals: the stimulator links ' ...
                'lead to %d different animals -- conflicting records, ' ...
                'refused and listed, not resolved through the cohort'], ...
                numel(viaStimulator));
            return;
        else
            % NO SUBJECT CAN BE RESOLVED: no response names it, the
            % session-epoch records no element, and the stimulator names no
            % animal. Decided by Jess Haley, 2026-10-21 ("a"): such a
            % presentation becomes a STANDALONE `item` (the same ordered,
            % timed list of stimuli, id preserved) with no manipulation and
            % no subject claim, instead of being left as v1.
            report.no_subject_reason = noAnimalReason(resolver, presentationId);
            report.sibling_subjects = siblingCount(resolver, presentationId);
            report.standalone = true;
        end
    end
end

entityId = '';
if report.standalone
    % no entity: the item is a value, not a statement
elseif numel(animals) > 1
    report.several_animals = numel(animals);
    report.animals = animals(:)';
    if isempty(options.CohortIdFor)
        report.reason = sprintf(['several animals: the %s route resolves to %d ' ...
            'animals in this session, and no session cohort was supplied'], ...
            report.animal_source, numel(animals));
        return;
    end
    entityId = char(options.CohortIdFor(sessionId));
    report.distributive = true;
else
    entityId = animals{1};
    report.animals = animals(:)';
end

stimulatorId = depValue(v1Body, 'stimulus_element_id');
report.instrument_resolved = ~isempty(stimulatorId);

block = presentationBlock(v1Body);
stimuli = stimulusArray(block);
order   = orderVector(block);
report.stimuli_read = numel(stimuli);
report.trials       = numel(order);
if isempty(stimuli) || isempty(order)
    report.reason = 'no stimuli / no presentation_order';
    return;
end

% ---- the supplied enumeration (Hartley) -------------------------------------
if ~isempty(sequence)
    [itemIds, frameOrder, frameTimes, duration, why] = readSequence(sequence);
    report.basis_source = 'supplied enumeration (hartley_calc)';
    report.shared_refs  = numel(itemIds);
    report.frames       = numel(frameOrder);
    if ~isempty(why)
        report.reason = why;
        report.basis_source = 'not read';
        report.shared_refs = 0;
        report.frames = 0;
        return;
    end
    value = struct('item', frameOrder - 1);
    keys = [];
    if ~isempty(frameTimes)
        keys = timeKey(frameTimes);
        if duration > 0
            value.offset = frameTimes + duration;
        end
        report.trials_with_timing = numel(frameTimes);
        report.timing_source = 'frameTimes (hartley_calc)';
    end
    manipBody = itemBody(report.standalone, presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, keys, report.distributive);
    return;
end

% ---- the presentation's own stimuli ----------------------------------------
outOfRange = sum(order < 1 | order > numel(stimuli) | order ~= floor(order));
report.trials_out_of_range = outOfRange;
if outOfRange > 0
    report.reason = 'presentation_order indexes outside the stimuli list';
    return;
end

% Every kind stimulusRecipe describes folds ([non-grating stimuli as
% methods], Jess Haley 2026-10-21); the rest is refused by class.
foldable = {'grating', 'blank', 'periodicstim_bars', 'periodicstim_other', ...
    'stochasticgridstim', 'blinkingstim', 'shapemoviestim'};
refusedKinds = {};
for i = 1:numel(stimulusKinds)
    if ~any(strcmp(stimulusKinds{i}, {'grating', 'blank'}))
        report.non_grating_stimuli = report.non_grating_stimuli + 1;
    end
    if ~any(strcmp(stimulusKinds{i}, foldable)) ...
            && ~any(strcmp(stimulusKinds{i}, refusedKinds))
        refusedKinds{end+1} = stimulusKinds{i}; %#ok<AGROW>
    end
end
if ~isempty(refusedKinds)
    labels = cellfun(@newStimKindLabel, sort(refusedKinds), 'UniformOutput', false);
    report.reason = ['a stimulus kind with no recipe, refused by class: ' ...
        strjoin(labels, '; ')];
    return;
end

% one recipe per stimulus, deduplicated by content
distinct = {};
isBlank = false(1, 0);
mapToDistinct = zeros(1, numel(stimuli));
for i = 1:numel(stimuli)
    r = ndi.migrate.internal.stimulusRecipe(stimParameters(stimuli, i), stimulusKinds{i});
    hit = 0;
    for d = 1:numel(distinct)
        if isequal(distinct{d}, r); hit = d; break; end
    end
    if hit == 0
        distinct{end+1} = r; %#ok<AGROW>
        isBlank(end+1) = strcmp(stimulusKinds{i}, 'blank'); %#ok<AGROW>
        hit = numel(distinct);
    end
    mapToDistinct(i) = hit;
end
report.distinct_stimuli = numel(distinct);
report.blank_stimuli = sum(isBlank);

methodBodies = cell(1, numel(distinct));
itemIds = cell(1, numel(distinct));
for d = 1:numel(distinct)
    methodBodies{d} = ndi.migrate.internal.stimulusMethod(distinct{d}, sessionId, datestamp);
    itemIds{d} = methodBodies{d}.base.id;
end

value = struct('item', mapToDistinct(order) - 1);   % 0-based (T14)
if sum(isBlank) == 1
    value.control_item = find(isBlank) - 1;
end

times = struct([]);
if isfield(block, 'presentation_time') && isstruct(block.presentation_time)
    times = block.presentation_time;
end
[onsets, offsets, timingOk] = trialTiming(times, numel(order));
report.trials_with_timing = sum(timingOk);
keys = [];
if ~isempty(timingOk) && all(timingOk)
    report.timing_source = 'inline (deprecated writer form)';
    keys = timeKey(onsets);
    value.offset = offsets;
else
    report.timing_source = 'none in the document body (presentation_time.bin not read here)';
end

manipBody = itemBody(report.standalone, presentationId, sessionId, datestamp, ...
    entityId, stimulatorId, itemIds, value, keys, report.distributive);
end

% ===================== the manipulation ===================================

function b = itemBody(standalone, presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, keys, distributive)
if standalone
    b = standaloneItem(presentationId, sessionId, datestamp, itemIds, value, keys);
else
    b = itemManipulation(presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, keys, distributive);
end
end

function d = standaloneItem(presentationId, sessionId, datestamp, itemIds, value, keys)
%STANDALONEITEM The presentation's `item` on its own: the ordered, timed list
%   of stimuli shown, base.id = the v1 presentation id, and no manipulation,
%   subject or instrument (Jess Haley, 2026-10-21, "a"). `item` is concrete
%   on did-schema #88 (draft/item.json declares no `abstract`).
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
fields = struct('value', value);
if ~isempty(keys)
    fields.keys = keys;
end
d = did2.build.document('item', fields, ...
    'Edges', struct('item_id', {itemIds}), ...
    'SessionId', sessionId, 'Id', presentationId, ...
    'CreationTimestamp', datestamp, 'Validate', false);
end

function m = itemManipulation(presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, keys, distributive)
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
% did2.build insists on the interaction's time_reference_id min_count; the
% reference is minted by the caller ("during the session"), so a stand-in
% satisfies the builder and is swapped for the transient marker straight
% after (the lightsheet migrator's pattern, DID-matlab lightsheet_zarr_pyramid).
standIn = [presentationId '_time_reference_pending'];
args = {'Method', 'visual stimulation', ...
    'TimeReferenceIds', {standIn}, ...
    'Edges', struct('item_id', {itemIds}), ...
    'SessionId', sessionId, 'Id', presentationId, ...
    'CreationTimestamp', datestamp, 'Validate', false};
if ~isempty(stimulatorId)
    args = [args, {'InstrumentId', stimulatorId}];
end
if ~isempty(keys)
    args = [args, {'Keys', keys}];
end
if distributive
    args = [args, {'Fields', struct('distributive', true)}];
end
m = did2.build.statement('manipulation', entityId, 'visual stimulus', ...
    value, 'ValueKind', 'item', args{:});
m = removeEdge(m, 'time_reference_id');
m = addEdge(m, did2.convert.mintSessionDuring('marker'), presentationId);
end

function k = timeKey(onsets)
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
k = did2.build.key('time', numel(onsets), 'Unit', 'second', ...
    'Values', double(onsets(:)'));
end

function b = removeEdge(b, name)
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
keep = arrayfun(@(d) ~strcmp(char(d.name), name), b.depends_on);
b.depends_on = b.depends_on(keep);
end

function b = addEdge(b, name, value)
% Shaped like the entries already there ({name, document_id} from did2.build).
if ~isfield(b, 'depends_on') || isempty(b.depends_on)
    b.depends_on = struct('name', name, 'document_id', value);
    return;
end
e = struct();
f = fieldnames(b.depends_on);
for i = 1:numel(f); e.(f{i}) = ''; end
e.name = name;
if isfield(e, 'document_id'); e.document_id = value; else; e.value = value; end
b.depends_on(end+1) = e;
end

% ===================== refusals ===========================================

function reason = noAnimalReason(resolver, presentationId)
nAny = resolver.epochElementCountUnscoped(presentationId);
if nAny == 0
    reason = ['no responding animal; the epoch has no recorded element in ' ...
        'any session and the stimulator element names no subject'];
    return;
end
sibling = resolver.subjectsViaEpochSibling(presentationId);
if numel(sibling) == 1
    reason = ['no responding animal; the epoch records no element in THIS ' ...
        'session, the stimulator element names no subject, and exactly one ' ...
        'sibling session carries the epoch name -- fork 2 attribution is ' ...
        'DISARMED (team call)'];
elseif numel(sibling) > 1
    reason = sprintf(['no responding animal; the stimulator element names no ' ...
        'subject, and the epoch name records only in sibling session(s), ' ...
        'resolving to %d subjects -- ambiguous across sessions'], numel(sibling));
else
    reason = ['no responding animal; the stimulator element names no subject, ' ...
        'and the epoch name records in a sibling session, but no element ' ...
        'there resolves to a subject'];
end
end

function n = siblingCount(resolver, presentationId)
n = 0;
if resolver.epochElementCountUnscoped(presentationId) > 0
    n = numel(resolver.subjectsViaEpochSibling(presentationId));
end
end

% ===================== the supplied enumeration ===========================

function [itemIds, order, frameTimes, duration, why] = readSequence(sequence)
itemIds = {}; order = []; frameTimes = []; duration = 0; why = '';
if ~isstruct(sequence) || ~isscalar(sequence)
    why = 'supplied sequence is not a scalar struct';
    return;
end
if ~isfield(sequence, 'item_ids') || ~iscell(sequence.item_ids) ...
        || isempty(sequence.item_ids)
    why = 'supplied sequence carries no item_ids';
    return;
end
itemIds = sequence.item_ids(:)';
for k = 1:numel(itemIds)
    if isempty(itemIds{k}) || ~(ischar(itemIds{k}) ...
            || (isstring(itemIds{k}) && isscalar(itemIds{k})))
        why = sprintf('supplied item_ids(%d) is not a non-empty id', k);
        itemIds = {};
        return;
    end
    itemIds{k} = char(itemIds{k});
end
if ~isfield(sequence, 'order') || ~isnumeric(sequence.order) || isempty(sequence.order)
    why = 'supplied sequence carries no order';
    itemIds = {};
    return;
end
order = double(sequence.order(:)');
bad = sum(order < 1 | order > numel(itemIds) | order ~= floor(order));
if bad > 0
    why = sprintf('supplied order has %d entr(ies) outside the item_ids list', bad);
    itemIds = {}; order = [];
    return;
end
if isfield(sequence, 'frame_times') && isnumeric(sequence.frame_times) ...
        && ~isempty(sequence.frame_times)
    frameTimes = double(sequence.frame_times(:)');
    if numel(frameTimes) ~= numel(order)
        why = sprintf('supplied frame_times has %d entr(ies) for %d frame(s)', ...
            numel(frameTimes), numel(order));
        itemIds = {}; order = []; frameTimes = [];
        return;
    end
end
if isfield(sequence, 'duration') && isnumeric(sequence.duration) ...
        && isscalar(sequence.duration)
    duration = double(sequence.duration);
end
end

% ===================== the NewStim class recogniser ========================

function kind = newStimKind(params)
%NEWSTIMKIND The NewStim class whose verify function's required fields a
%   parameter set carries (Jess Haley, 2026-10-21: recognise the class, not a
%   word). A blank is a blank whatever its class (isblank = 1). A periodicstim
%   is a grating only with imageType 1 (square) or 2 (sine); imageType 0 is a
%   uniform field (flashed bars).
kind = 'unrecognised';
if ~isstruct(params) || ~isscalar(params)
    return;
end
blankNames = {'isblank', 'is_blank', 'blank'};
for k = 1:numel(blankNames)
    if isfield(params, blankNames{k}) && ~isempty(params.(blankNames{k}))
        v = params.(blankNames{k});
        if (isnumeric(v) || islogical(v)) && logical(v(1))
            kind = 'blank';
            return;
        end
    end
end
classes = struct( ...
    'name', {'periodicstim', 'stochasticgridstim', 'blinkingstim', ...
             'shapemoviestim', 'hartleystim'}, ...
    'required', { ...
        {'imageType', 'animType', 'flickerType', 'angle', 'chromhigh', ...
         'chromlow', 'sFrequency', 'sPhaseShift', 'distance', 'tFrequency', ...
         'barWidth', 'rect', 'nCycles', 'contrast', 'background', ...
         'backdrop', 'barColor', 'nSmoothPixels', 'fixedDur', ...
         'windowShape', 'loops', 'dispprefs'}, ...                  % verifyperiodicstim.m
        {'BG', 'dist', 'values', 'rect', 'pixSize', 'N', 'randState', ...
         'dispprefs'}, ...                                           % verifystochasticgridstim.m
        {'BG', 'value', 'rect', 'pixSize', 'repeat', 'bgpause', 'fps', ...
         'randState', 'dispprefs'}, ...                              % @blinkingstim verify.m
        {'rect', 'BG', 'scale', 'fps', 'N', 'isi', 'dispprefs'}, ... % verifyshapemoviestim.m
        {'M', 'K_absmax', 'L_absmax', 'sfmax'}});
matched = {};
for c = 1:numel(classes)
    if all(isfield(params, classes(c).required))
        matched{end+1} = classes(c).name; %#ok<AGROW>
    end
end
if isempty(matched)
    return;
end
if numel(matched) > 1
    kind = 'ambiguous';
    return;
end
kind = matched{1};
if strcmp(kind, 'periodicstim')
    t = params.imageType;
    if isnumeric(t) && isscalar(t) && any(t == [1 2])
        kind = 'grating';
    elseif isnumeric(t) && isscalar(t) && t == 0
        kind = 'periodicstim_bars';
    else
        kind = 'periodicstim_other';
    end
end
end

function label = newStimKindLabel(kind)
switch kind
    case 'periodicstim_bars'
        label = 'periodicstim imageType 0 (a uniform field: bars, not a grating)';
    case 'periodicstim_other'
        label = 'periodicstim with an imageType other than 0, 1 or 2';
    case 'stochasticgridstim'
        label = 'stochasticgridstim (noise)';
    case 'blinkingstim'
        label = 'blinkingstim (sparse blinking squares)';
    case 'shapemoviestim'
        label = 'shapemoviestim (the drawn shapes are not in the v1 document)';
    case 'hartleystim'
        label = 'hartleystim (a generator recipe; no hartley_calc enumeration supplied)';
    case 'ambiguous'
        label = 'a parameter set matching more than one NewStim class';
    otherwise
        label = 'an unrecognised parameter set (no NewStim class matches)';
end
end

function k = newStimKindCounts()
k = struct('grating', 0, 'blank', 0, 'periodicstim_bars', 0, ...
    'periodicstim_other', 0, 'stochasticgridstim', 0, 'blinkingstim', 0, ...
    'shapemoviestim', 0, 'hartleystim', 0, 'ambiguous', 0, 'unrecognised', 0);
end

% ===================== report =============================================

function r = newReport()
%NEWREPORT Denominators first and unconditionally (Rule 5): a refusal prints
%   the same SHAPE as a success.
r = struct( ...
    'stimuli_read',        0, ...
    'non_grating_stimuli', 0, ...
    'stimulus_kinds',      newStimKindCounts(), ...
    'distinct_stimuli',    0, ...
    'blank_stimuli',       0, ...
    'trials',              0, ...
    'trials_out_of_range', 0, ...
    'trials_with_timing',  0, ...
    'timing_source',       'not read', ...
    'basis_source',        'the presentation''s own stimuli list', ...
    'shared_refs',         0, ...
    'frames',              0, ...
    'subjects_resolved',   0, ...
    'sibling_subjects',    0, ...
    'stimulator_subjects', 0, ...
    'several_animals',     0, ...
    'animals',             {{}}, ...
    'distributive',        false, ...
    'standalone',          false, ...
    'no_subject_reason',   '', ...
    'instrument_resolved', false, ...
    'epoch_id',            '', ...
    'animal_source',       '', ...
    'reason',              '');
end

% ===================== v1 readers =========================================

function block = presentationBlock(body)
block = struct();
if isfield(body, 'stimulus_presentation') && isstruct(body.stimulus_presentation)
    block = body.stimulus_presentation;
end
end

function stimuli = stimulusArray(block)
% jsondecode gives a scalar struct (one stimulus), a struct array (uniform
% key sets) or a cell (differing key sets); all three are real.
stimuli = struct([]);
if ~isfield(block, 'stimuli'); return; end
raw = block.stimuli;
if isstruct(raw)
    stimuli = raw(:)';
elseif iscell(raw)
    keep = struct('parameters', {});
    for k = 1:numel(raw)
        if isstruct(raw{k}) && isscalar(raw{k}) && isfield(raw{k}, 'parameters')
            keep(end+1) = struct('parameters', raw{k}.parameters); %#ok<AGROW>
        end
    end
    stimuli = keep;
end
end

function order = orderVector(block)
order = [];
if ~isfield(block, 'presentation_order'); return; end
raw = block.presentation_order;
if isnumeric(raw) && ~isempty(raw)
    order = double(raw(:)');
end
end

function [onsets, offsets, ok] = trialTiming(times, nTrials)
onsets  = zeros(1, nTrials);
offsets = zeros(1, nTrials);
ok      = false(1, nTrials);
if ~isstruct(times) || isempty(times); return; end
for k = 1:nTrials
    if numel(times) < k; return; end
    [onset, haveOnset]   = numericField(times(k), 'onset');
    [offset, haveOffset] = numericField(times(k), 'offset');
    if ~haveOnset || ~haveOffset; continue; end
    onsets(k)  = onset;
    offsets(k) = offset;
    ok(k)      = true;
end
end

function [v, present] = numericField(s, name)
v = 0; present = false;
if isstruct(s) && isfield(s, name) && isnumeric(s.(name)) && ~isempty(s.(name))
    v = double(s.(name)(1));
    present = true;
end
end

function params = stimParameters(stimuli, idx)
params = struct();
if isstruct(stimuli) && idx >= 1 && numel(stimuli) >= idx ...
        && isfield(stimuli(idx), 'parameters') ...
        && isstruct(stimuli(idx).parameters) ...
        && isscalar(stimuli(idx).parameters)
    params = stimuli(idx).parameters;
end
end

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name) ...
        && ~isempty(body.base.(name))
    v = body.base.(name);
end
end

function id = epochIdOf(body)
id = '';
if isfield(body, 'epochid') && isstruct(body.epochid) ...
        && isfield(body.epochid, 'epochid')
    id = char(body.epochid.epochid);
end
end

function v = depValue(body, name)
v = '';
if ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if isstruct(d) && isfield(d, 'name') && strcmp(char(d.name), name)
        for f = {'value', 'document_id'}
            if isfield(d, f{1}) && ~isempty(d.(f{1}))
                v = char(d.(f{1}));
                return;
            end
        end
    end
end
end
