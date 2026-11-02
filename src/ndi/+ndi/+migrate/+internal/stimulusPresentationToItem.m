function [manipBody, methodBodies, report, softwareBodies, controlCalcs] = ...
        stimulusPresentationToItem(v1Body, resolver, sequence, options)
%STIMULUSPRESENTATIONTOITEM Decompose one legacy stimulus_presentation into the
%   did-schema #88 stimulus shape: N deduplicated standalone `method`
%   documents (one per distinct stimulus, given as a recipe) plus ONE
%   `manipulation` (value kind `item`) whose `item` value is the playlist into them.
%
%   [MANIP, METHODS, REPORT] = stimulusPresentationToItem(V1BODY, RESOLVER)
%   [MANIP, METHODS, REPORT, SOFTWARE, CONTROLCALCS] = stimulusPresentationToItem(...)
%   [...] = stimulusPresentationToItem(V1BODY, RESOLVER, SEQUENCE)
%   [...] = stimulusPresentationToItem(..., 'CohortIdFor', @(sessionId) id)
%   [...] = stimulusPresentationToItem(..., 'ControlRecords', {v1Control, ...})
%   [...] = stimulusPresentationToItem(..., 'PresentationTimeFile', PATH, ...
%           'PresentationTimeFileStatus', WHY)   (WHY: why PATH is '', from
%           ndi.migrate.internal.v1AttachedFile)
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
%                     dimensions     ONE: a presentation, term OBI:0000807
%                                    'presentation of stimulus' (Decided by
%                                    Jess Haley, 2026-10-22 [presentation
%                                    dimension term]), n = trials (frames on
%                                    the SEQUENCE path)
%                     covariates     along that dimension (did-schema
%                                    V_eta_data_body_model_plan.md AMENDMENT 6,
%                                    Decided by Jess Haley, 2026-10-22
%                                    [covariates] / [onset time]):
%                                      'onset time'  (EMPTY:0000368) each
%                                                    trial's onset, s, see TIMING
%                                      'offset time' (EMPTY:0000369) each
%                                                    trial's end, s, see TIMING
%                                      'control condition' (XCO:0000099,
%                                                    logical) see CONTROL
%                                    (the two time terms: Decided by Jess
%                                    Haley, 2026-10-22 [onset and offset
%                                    terms])
%                     files          the v1 document's `files` block, carried
%                                    unchanged: presentation_time.bin stays
%                                    attached as the presentation's raw source
%                                    ([presentation times from the file])
%                     method         inline {term 'visual stimulation'}: how
%                                    the sequence was delivered (the plan's
%                                    own example); what each stimulus was is
%                                    on the documents the playlist names. On
%                                    the SEQUENCE (Hartley) path its
%                                    `parameters` are the generator settings
%                                    the shared basis does not read (see
%                                    HARTLEY GENERATOR SETTINGS)
%                     statement.distributive  true on a cohort manipulation
%                     software_id    the presentation's `app` (see SOFTWARE)
%     SOFTWARE      the `software` entities (with version assertions) minted
%                   from the presentation's `app` and for each control
%                   calculation (its app, OS and interpreter); the caller
%                   adds them to the documents it folds, and
%                   ndi.migrate.local's software dedup merges duplicates
%     CONTROLCALCS  one `calculation` per v1 control_stimulus_ids record
%                   (see CONTROL PAIRING), carrying the same session marker
%                   as the manipulation
%                   Its time reference is NOT minted here: the edge is
%                   replaced by the did2.convert.mintSessionDuring marker,
%                   and ndi.migrate.local mints "during the session" for it
%                   (the lightsheet decision, Jess 2026-10-14, option A). The
%                   epoch anchor the plan prefers needs the clocktype that
%                   lives in presentation_time.bin; when the file is read, its
%                   clocktype is reported (REPORT.timing_clocktype) but the
%                   anchor is still "during the session".
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
%   resolve to no subject is a standalone item too (Jess Haley, 2026-10-26
%   [unresolved recorded elements make a standalone item], "1 a"); the
%   stimulator route is not tried for it.
%
%   SEQUENCE (optional) supplies an enumeration the presentation lacks:
%     .item_ids     cell of ALREADY-MINTED method ids
%     .order        [1 x nFrames] 1-based index into item_ids, per frame
%     .frame_times  [1 x nFrames] frame onsets, seconds (optional)
%     .duration     seconds per frame (optional; gives the offsets)
%   ndi.migrate.internal.hartleyBasisGratings builds it from the hartley_calc
%   documents that reference the presentation.
%
%   HARTLEY GENERATOR SETTINGS. Decided by Jess Haley, 2026-10-30 [Hartley
%   settings on the inline method] (did-schema
%   V_eta_go_forward_class_audit.md, answering docs/V2_PLAN.md G35; under
%   [method shared plus own], 2026-10-22): on the SEQUENCE path the methods
%   the playlist names are the session's SHARED basis, minted once, so a
%   generator key the basis does not read (randState, rect, distance,
%   chromhigh, reps, ...; the basis reads M, K_absmax, L_absmax, fps,
%   contrast, sfmax) is a parameter of this manipulation's own inline
%   `method` (ndi.migrate.internal.stimulusRecipe kind 'hartley_generator').
%   REPORT.hartley_own_parameters counts them. A STANDALONE item has no
%   method, so such a presentation with no subject is still refused under
%   carry-080, as is a second value of a key the basis reads.
%
%   CONTROL (Decided by Jess Haley, 2026-10-22 [control as covariate],
%   did-schema V_eta_stimulus_response_model_plan.md). 'ControlRecords' are
%   the v1 control_stimulus_ids documents about this presentation. A v1 entry
%   is a TRIAL number (an index into presentation_order; tuning_response's
%   control_stimulus writes, per trial, the trial of its control), so the
%   trials the record names are the controls: the covariate is true at
%   unique(entries), false elsewhere. A record whose value is NaN / empty (no
%   trial was a control) gives all false. No record: no covariate. A record
%   that cannot be placed -- an entry outside 1..trials or NaN among numbers
%   ('unmappable'), a non-NaN record on the SEQUENCE path whose dimension is
%   frames, not trials ('no position map'), or several records that disagree
%   ('conflicting') -- gives no covariate, and REPORT.control_unfolded_reason
%   says why; the caller leaves such records as v1. REPORT.control_records
%   (given), .control_records_folded and .control_true count what happened.
%
%   SOFTWARE. Decided by Jess Haley, 2026-10-26 [presentation app is
%   software] (did-schema V_eta_go_forward_class_audit.md; rule R1,
%   TEAM-SIGN-OFF [software]): the v1 `app` block (name, version, url) becomes
%   a `software` entity (ndi.migrate.internal.appSoftware) referenced by the
%   manipulation's `software_id`: the software that PRODUCED the statement,
%   here the decoder that wrote the presentation ([software_id is what
%   produced the statement], Jess Haley, 2026-10-26). A standalone item has no software edge: its
%   software is minted unreferenced (REPORT.software_unreferenced).
%   THE RUN ENVIRONMENT. Decided by Jess Haley, 2026-10-26 [run environment
%   on interactions] (built in did-schema #131): `operating_system_id` and
%   `interpreter_id` are on `interaction`, so the app's os (os_version) and
%   interpreter (interpreter_version) are `software` entities on the
%   manipulation's two edges, as a calculation's are
%   (ndi.migrate.internal.softwareEntity). REPORT.run_environment_written
%   counts the edges written; a standalone item has neither edge, so there
%   they are not minted and REPORT.run_environment_unplaced names the fields
%   (as does a version stated with no name).
%
%   CONTROL PAIRING. Decided by Jess Haley, 2026-10-26 [control pairing is a
%   calculation] (replaces [control selection on the presentation method],
%   amends [control as covariate]): each v1 control_stimulus_ids record is
%   what NDI's tuning_response computed afterwards -- the pairing of each
%   presented trial with its control trial -- and becomes a `calculation`
%   about the presentation, base.id = THE RECORD's id (so every inbound edge
%   keeps resolving):
%     entity_id        the manipulation's entity (the animal, or the cohort,
%                      `distributive` as the manipulation)
%     input_id         the presentation
%     software_id      the record's `app` (ndi_app_tuning_response)
%     operating_system_id / interpreter_id   the record's app OS and
%                      interpreter, as software entities
%     method           {term 'control stimulus pairing' (a label), parameters:
%                      the rule's fields verbatim, each its v1 name as a label
%                      variable -- method, controlid, controlid_value}
%     value            kind `count`, one per trial along ONE dimension
%                      'presentation of stimulus' (OBI:0000807, n = trials):
%                      the 0-based position of that trial's control trial
%                      (v1 writes 1-based trial numbers; T14). Variable
%                      'control trial' (a label).
%   The record is converted only when ALL of it is placed ([generic stage is
%   lossless]); otherwise it is left as it is (the end of ndi.migrate.local
%   carries it as v1) and REPORT.control_carried says why: a standalone item
%   (no subject), a frame sequence, an entry that is NaN / empty / not a
%   trial number, an entry count other than the trials, a field or edge
%   outside NDI's template (carry-100, [control record fields split], Jess
%   Haley, 2026-10-27), or an app naming no program.
%   The `control condition` covariate stays on the presentation as a
%   convenience (recoverable from the records), whatever becomes of them.
%
%   TIMING. Decided by Jess Haley, 2026-10-22 [presentation times from the
%   file] (did-schema V_eta_stimulus_response_model_plan.md). The current v1
%   writer puts the per-trial times in the attached file presentation_time.bin
%   (NDI origin/main +ndi/+app/+stimulus/decoder.m, "we now put this in a
%   file", written by ndi.database.fun.write_presentation_time_structure and
%   read back by ndi.database.fun.read_presentation_time_structure). In order:
%     1. 'PresentationTimeFile', the path of those bytes on this computer
%        (the caller finds them; '' when they are not here): read with NDI's
%        own reader. Used when it holds one entry per trial and every onset
%        is a finite number: `onset time` from `onset`, and `offset time` from
%        `offset` when every offset is finite. REPORT.timing_source
%        'presentation_time.bin'.
%     2. the deprecated inline `presentation_time` block (decoder.m's "old
%        way"), when EVERY trial has an onset and an offset.
%     3. otherwise no onset or offset covariate ("nobody looked" is not "it
%        happened at t=0").
%   REPORT.timing_file says what became of the file (see newReport). On the
%   SEQUENCE path the dimension is FRAMES, not trials, so the per-trial file
%   times do not index it; the supplied frame times are used and the file is
%   not read ('not used: the dimension is frames').
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
    options.ControlRecords = {}
    options.PresentationTimeFile = ''
    options.PresentationTimeFileStatus = ''
    % [generic stage is lossless] (Jess Haley, 2026-10-25): true (the default,
    % the generic stage) refuses a presentation with any field the
    % decomposition does not write; false runs the recipes regardless -- the
    % NewStim recipe as a per-software workbook default ([NewStim recipes are
    % a default], 2026-10-25), and the tests of the recipes themselves.
    options.LeaveUnplaced (1,1) logical = true
end

manipBody = []; methodBodies = {}; softwareBodies = {}; controlCalcs = {};
report = newReport();

presentationId = baseField(v1Body, 'id', '');
sessionId      = ndi.v2.sessionIdOf(v1Body);
datestamp      = baseField(v1Body, 'datestamp', '');
report.epoch_id = epochIdOf(v1Body);
if declaresFile(v1Body, 'presentation_time.bin')
    report.timing_file = 'declared, not located';
    if ~isempty(options.PresentationTimeFileStatus)
        report.timing_file = char(options.PresentationTimeFileStatus);
    end
end
if isempty(presentationId) || isempty(sessionId) || isempty(datestamp)
    % carry-register: carry-083
    report.reason = '[carry-083] base id / session_id / datestamp incomplete';
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

% ---- lossless: nothing the decomposition cannot place ----------------------
% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): a presentation with
% any v1 field the item, its methods and its covariates do not write is
% REFUSED: left as it is, so the end of ndi.migrate.local carries it as v1.
% Decided by Jess Haley, 2026-10-27 [unread stimulus parameters are method
% parameters] ("Q6 yes", did-schema V_eta_go_forward_class_audit.md): a
% grating's or a blank's `parameters` key that gratingRecipe does not read is
% now a method parameter entry (ndi.migrate.internal.stimulusRecipe), so it no
% longer refuses the presentation; a field outside NDI's template (a block
% field beside stimuli / presentation_order / presentation_time, a stimulus
% field beside `parameters`) is carried under carry-100 (malformed). Still
% refused under carry-080, because the decision names no home for them (see
% unplacedPresentationFields): a second value of a key gratingRecipe (or the
% Hartley basis) reads one of. A Hartley generator parameter the SHARED basis
% does not read is the manipulation's inline method parameter ([Hartley
% settings on the inline method], Jess Haley, 2026-10-30); GENERATORKEYS
% lists them, and they refuse only a standalone item (below), which has no
% method to hold them.
[outside, unplaced, generatorKeys] = unplacedPresentationFields(earlyBlock, ...
    earlyStimuli, stimulusKinds, ~isempty(sequence));
% the `app` block the writer adds (ndi.app newdocument: app.json's seven
% fields): a field outside them is outside the template too, carry-100
% ([fields outside the template are malformed]; the renamed app_name /
% app_version are such fields since DID-matlab #351 deleted universalRenames,
% [rename clashes are malformed])
outside = [outside, appFieldsOutsideTemplate(v1Body)];
report.unplaced_fields = [outside, unplaced];
if ~isempty(report.unplaced_fields) && options.LeaveUnplaced
    if ~isempty(outside)
        % carry-register: carry-100
        report.reason = ['[carry-100] outside the stimulus_presentation template ' ...
            '(carried as v1): ' strjoin(outside, ', ')];
    else
        % carry-register: carry-080
        report.reason = ['[carry-080] unplaced (carried as v1): ' strjoin(unplaced, ', ')];
    end
    return;
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
        viaStimulator = {};
        if nEl == 0
            viaStimulator = resolver.subjectsViaStimulator(presentationId);
        end
        report.stimulator_subjects = numel(viaStimulator);
        if nEl > 0
            % The epoch records elements but none resolves to a subject.
            % Decided by Jess Haley, 2026-10-26 [unresolved recorded elements
            % make a standalone item] ("1 a"; did-schema
            % V_eta_go_forward_class_audit.md): such a presentation becomes a
            % STANDALONE `item`, as one with no element at all does
            % ([presentation with no subject], 2026-10-21), instead of being
            % carried as v1. The stimulator route is not tried: the epoch's
            % own recorded elements outrank it, as before.
            report.no_subject_reason = sprintf(['no responding animal; the ' ...
                'epoch''s %d recorded element(s) resolve to no subject'], nEl);
            report.sibling_subjects = siblingCount(resolver, presentationId);
            report.standalone = true;
        elseif numel(viaStimulator) == 1
            animals = viaStimulator;
            report.animal_source = 'stimulator';
        elseif numel(viaStimulator) > 1
            % Decision 4: different animals by different stimulator links
            % are conflicting records, not a shared event.
            report.several_animals = numel(viaStimulator);
            % carry-register: carry-081
            report.reason = sprintf(['[carry-081] several animals: the stimulator links ' ...
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

if report.standalone && ~isempty(generatorKeys) && options.LeaveUnplaced
    % [Hartley settings on the inline method] puts the generator keys on the
    % MANIPULATION's inline method; a standalone item has none, so they have
    % no home and the presentation is carried as v1
    report.unplaced_fields = [report.unplaced_fields, generatorKeys];
    % carry-register: carry-080
    report.reason = ['[carry-080] unplaced (carried as v1; a standalone item ' ...
        'has no method for them): ' strjoin(generatorKeys, ', ')];
    return;
end

entityId = '';
if report.standalone
    % no entity: the item is a value, not a statement
elseif numel(animals) > 1
    report.several_animals = numel(animals);
    report.animals = animals(:)';
    if isempty(options.CohortIdFor)
        % NOT a carry: [conflicting animal records need a map] (Jess Haley,
        % 2026-10-26) keeps carry-081 for conflicting records only; animals
        % recorded together get one manipulation on the session's standing
        % cohort (stimulus plan rule 2, T17 amendment). ndi.migrate.local
        % always supplies CohortIdFor (cohortIdOf mints one per session), so
        % this refusal is reached only by a caller that supplies none.
        report.reason = sprintf(['several animals: the %s route resolves to %d ' ...
            'animals in this session, and the caller supplied no session ' ...
            'cohort (CohortIdFor)'], ...
            report.animal_source, numel(animals));
        return;
    end
    entityId = char(options.CohortIdFor(sessionId));
    report.distributive = true;
else
    entityId = animals{1};
    report.animals = animals(:)';
end
report.entity_id = entityId;

stimulatorId = depValue(v1Body, 'stimulus_element_id');
report.instrument_resolved = ~isempty(stimulatorId);

block = presentationBlock(v1Body);
stimuli = stimulusArray(block);
order   = orderVector(block);
report.stimuli_read = numel(stimuli);
report.trials       = numel(order);
if isempty(stimuli) || isempty(order)
    % carry-register: carry-083
    report.reason = '[carry-083] no stimuli / no presentation_order';
    return;
end

% ---- the supplied enumeration (Hartley) -------------------------------------
if ~isempty(sequence)
    [itemIds, frameOrder, frameTimes, duration, why] = readSequence(sequence);
    report.basis_source = 'supplied enumeration (hartley_calc)';
    report.shared_refs  = numel(itemIds);
    report.frames       = numel(frameOrder);
    if ~isempty(why)
        % carry-register: carry-085 (readSequence's reasons, below)
        report.reason = ['[carry-085] ' why];
        report.basis_source = 'not read';
        report.shared_refs = 0;
        report.frames = 0;
        return;
    end
    value = struct('item', frameOrder - 1);
    onsets = []; offsets = [];
    if ~isempty(frameTimes)
        onsets = frameTimes;
        if duration > 0
            offsets = frameTimes + duration;
        end
        report.trials_with_timing = numel(frameTimes);
        report.timing_source = 'frameTimes (hartley_calc)';
    end
    [control, report] = controlCovariate(options.ControlRecords, ...
        numel(frameOrder), false, report);
    if ~isempty(options.PresentationTimeFile)
        report.timing_file = 'not used: the dimension is frames';
    end
    [dims, covs] = presentationAxes(numel(frameOrder), onsets, offsets, control);
    [softwareBodies, swIds, report] = presentationSoftware(v1Body, report);
    [controlCalcs, calcSoftware, report] = controlCalculations( ...
        options.ControlRecords, presentationId, entityId, numel(order), false, report);
    softwareBodies = [softwareBodies, calcSoftware];
    % [Hartley settings on the inline method] (Jess Haley, 2026-10-30)
    ownParams = [];
    if ~report.standalone
        [ownParams, report.hartley_own_parameters] = ...
            hartleyOwnParameters(stimParameters(stimuli, 1));
    end
    manipBody = itemBody(report.standalone, presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, dims, covs, report.distributive, ...
        '', swIds, ownParams);
    [manipBody, report] = carryFiles(manipBody, v1Body, report);
    return;
end

% ---- the presentation's own stimuli ----------------------------------------
outOfRange = sum(order < 1 | order > numel(stimuli) | order ~= floor(order));
report.trials_out_of_range = outOfRange;
if outOfRange > 0
    % carry-register: carry-083
    report.reason = '[carry-083] presentation_order indexes outside the stimuli list';
    return;
end

% Every kind stimulusRecipe describes folds ([non-grating stimuli as
% methods], Jess Haley 2026-10-21); the rest is refused by class.
foldable = {'grating', 'blank', 'periodicstim_bars', 'periodicstim_other', ...
    'stochasticgridstim', 'blinkingstim', 'shapemoviestim', 'hartleystim'};
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
    % carry-register: carry-084
    report.reason = ['[carry-084] a stimulus kind with no recipe, refused by class: ' ...
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
for d = 1:numel(distinct)
    t = distinct{d}.term;
    if isstruct(t); t = t.name; end
    switch t
        case 'flashed bar', report.flashed_bars = report.flashed_bars + 1;
        case 'uniform luminance field'
            report.uniform_fields_kept = report.uniform_fields_kept + 1;
    end
end

% THE PRESENTATION'S NOTES (statement.notes; the shared methods carry none)
notes = {};
if any(strcmp(stimulusKinds, 'shapemoviestim'))
    % Decided by Jess Haley, 2026-10-22 [shape movie note]
    notes{end+1} = ['The shape movies in this presentation are recorded by ' ...
        'their settings only (NewStim shapemoviestim SMSparams); the shapes ' ...
        'drawn on each frame (nframemovies) are not in the v1 record.'];
    report.shape_movie_note = true;
end
if any(strcmp(stimulusKinds, 'hartleystim'))
    % Decided by Jess Haley, 2026-10-22 [Hartley without enumeration]
    notes{end+1} = ['The individual Hartley gratings of this presentation are ' ...
        'not listed in the source (no hartley_calc enumeration); each Hartley ' ...
        'stimulus is recorded by its settings.'];
    report.hartley_without_enumeration = true;
end
notesText = strjoin(notes, ' ');
if ~isempty(notesText) && report.standalone
    report.notes_not_written_standalone = true;   % an item has no notes field
end

methodBodies = cell(1, numel(distinct));
itemIds = cell(1, numel(distinct));
for d = 1:numel(distinct)
    methodBodies{d} = ndi.migrate.internal.stimulusMethod(distinct{d}, sessionId, datestamp);
    itemIds{d} = methodBodies{d}.base.id;
end

value = struct('item', mapToDistinct(order) - 1);   % 0-based (T14)
% per TRIAL, its 0-based position in item_id (a v1 control_stimulus_ids entry
% names a trial, an index into presentation_order, not a stimulus)
report.trial_positions = value.item;

[onsets, offsets, report] = presentationTimes(block, ...
    options.PresentationTimeFile, numel(order), report);
[control, report] = controlCovariate(options.ControlRecords, numel(order), true, report);
[dims, covs] = presentationAxes(numel(order), onsets, offsets, control);
[softwareBodies, swIds, report] = presentationSoftware(v1Body, report);
[controlCalcs, calcSoftware, report] = controlCalculations( ...
    options.ControlRecords, presentationId, entityId, numel(order), true, report);
softwareBodies = [softwareBodies, calcSoftware];

manipBody = itemBody(report.standalone, presentationId, sessionId, datestamp, ...
    entityId, stimulatorId, itemIds, value, dims, covs, report.distributive, ...
    notesText, swIds);
[manipBody, report] = carryFiles(manipBody, v1Body, report);
end

% ===================== timing and the raw source ==========================

function [onsets, offsets, report] = presentationTimes(block, file, nTrials, report)
%PRESENTATIONTIMES The trial onsets and offsets, from presentation_time.bin,
%   else the deprecated inline block, else none (see TIMING in the help).
onsets = []; offsets = [];
[fOn, fOff, report] = fileTiming(file, nTrials, report);
if ~isempty(fOn)
    onsets = fOn;
    offsets = fOff;
    report.trials_with_timing = numel(fOn);
    report.timing_source = 'presentation_time.bin';
    return;
end
times = struct([]);
if isfield(block, 'presentation_time') && isstruct(block.presentation_time)
    times = block.presentation_time;
end
[iOn, iOff, timingOk] = trialTiming(times, nTrials);
report.trials_with_timing = sum(timingOk);
if ~isempty(timingOk) && all(timingOk)
    onsets = iOn;
    offsets = iOff;
    report.timing_source = 'inline (deprecated writer form)';
else
    report.timing_source = 'none';
end
end

function [onsets, offsets, report] = fileTiming(file, nTrials, report)
%FILETIMING Read presentation_time.bin with NDI's own reader. Empty ONSETS
%   when the file is not given or cannot be used; REPORT.timing_file says why.
onsets = []; offsets = [];
file = char(file);
if isempty(file)
    return;     % the caller's status ('not declared' / 'not on this computer') stands
end
if ~isfile(file)
    report.timing_file = 'not on this computer';
    return;
end
try
    [~, pt] = ndi.database.fun.read_presentation_time_structure(file);
catch ME
    report.timing_file = ['unreadable: ' ME.message];
    return;
end
report.timing_file_entries = numel(pt);
if numel(pt) ~= nTrials
    report.timing_file = sprintf('%d entr(ies) for %d trial(s)', numel(pt), nTrials);
    return;
end
on = nan(1, nTrials);
off = nan(1, nTrials);
for k = 1:nTrials
    [v, present] = numericField(pt(k), 'onset');
    if present; on(k) = v; end
    [v, present] = numericField(pt(k), 'offset');
    if present; off(k) = v; end
end
if nTrials == 0 || ~all(isfinite(on))
    report.timing_file = 'an onset is not a finite number';
    return;
end
report.timing_file = 'read';
ct = unique(arrayfun(@(e) char(e.clocktype), pt(:)', 'UniformOutput', false));
report.timing_clocktype = strjoin(ct, ', ');
onsets = on;
if all(isfinite(off))
    offsets = off;
end
end

function tf = declaresFile(v1Body, name)
tf = false;
if isstruct(v1Body) && isfield(v1Body, 'files') && isstruct(v1Body.files) ...
        && isscalar(v1Body.files) && isfield(v1Body.files, 'file_list')
    tf = any(strcmp(cellstr(v1Body.files.file_list), name));
end
end

function [b, report] = carryFiles(b, v1Body, report)
%CARRYFILES The v1 document's `files` block stays on the V2 document: its
%   presentation_time.bin is the presentation's raw source ([presentation
%   times from the file]). Locations are settled later, with every other
%   migrated document's, by ndi.migrate.internal.settleIngestedFiles.
if isempty(b) || ~isstruct(v1Body) || ~isfield(v1Body, 'files') ...
        || ~isstruct(v1Body.files) || isempty(v1Body.files)
    return;
end
b.files = v1Body.files;
if isfield(v1Body.files, 'file_list')
    report.files_attached = numel(cellstr(v1Body.files.file_list));
end
end

% ===================== the manipulation ===================================

function b = itemBody(standalone, presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, dims, covs, distributive, notes, ...
        swIds, methodParams)
if nargin < 12
    notes = '';
end
if nargin < 13
    swIds = struct('software', '', 'os', '', 'interpreter', '');
end
if nargin < 14
    methodParams = [];
end
if standalone
    b = standaloneItem(presentationId, sessionId, datestamp, itemIds, value, dims, covs);
else
    b = itemManipulation(presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, dims, covs, distributive, notes, ...
        swIds, methodParams);
end
end

function [params, n] = hartleyOwnParameters(p)
%HARTLEYOWNPARAMETERS The generator settings of a Hartley presentation's one
%   stimulus that the shared basis does not read, as inline method
%   parameters ([Hartley settings on the inline method], Jess Haley,
%   2026-10-30). N is how many v1 keys were placed. The variables are
%   stimulusRecipe's ('hartley_generator'); none is a variable of a basis
%   method (orientation, spatial phase, spatial frequency, contrast,
%   duration), as [method shared plus own] requires.
params = [];
n = 0;
if ~isstruct(p) || ~isscalar(p)
    return;
end
own = p;
read = intersect(fieldnames(p), hartleyReads());
if ~isempty(read)
    own = rmfield(p, read);
end
fn = fieldnames(own);
for k = 1:numel(fn)
    if ~isempty(own.(fn{k})) && ~strcmp(fn{k}, 'isblank')
        n = n + 1;
    end
end
if n == 0
    return;
end
recipe = ndi.migrate.internal.stimulusRecipe(own, 'hartley_generator');
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>   % most variables are labels
params = ndi.migrate.internal.recipeParameterList(recipe.parameters);
end

function names = hartleyReads()
% The generator keys the shared Hartley basis reads
% (ndi.migrate.internal.hartleyBasisGratings generatorSpec).
names = {'M', 'K_absmax', 'L_absmax', 'fps', 'contrast', 'sfmax'};
end

function d = standaloneItem(presentationId, sessionId, datestamp, itemIds, value, dims, covs)
%STANDALONEITEM The presentation's `item` on its own: the ordered, timed list
%   of stimuli shown, base.id = the v1 presentation id, and no manipulation,
%   subject or instrument (Jess Haley, 2026-10-21, "a"). `item` is concrete
%   on did-schema #88 (draft/item.json declares no `abstract`).
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
fields = struct('value', value, 'dimensions', {dims});
if ~isempty(covs)
    fields.covariates = covs;
end
d = did2.build.document('item', fields, ...
    'Edges', struct('item_id', {itemIds}), ...
    'SessionId', sessionId, 'Id', presentationId, ...
    'CreationTimestamp', datestamp, 'Validate', false);
end

function m = itemManipulation(presentationId, sessionId, datestamp, ...
        entityId, stimulatorId, itemIds, value, dims, covs, distributive, notes, ...
        swIds, methodParams)
if nargin < 11
    notes = '';
end
if nargin < 12
    swIds = struct('software', '', 'os', '', 'interpreter', '');
end
if nargin < 13
    methodParams = [];
end
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
if ~isempty(swIds.software)
    % [presentation app is software] (Jess Haley, 2026-10-26)
    args = [args, {'SoftwareId', swIds.software}];
end
% [run environment on interactions] (Jess Haley, 2026-10-26)
if ~isempty(swIds.os)
    args = [args, {'OperatingSystemId', swIds.os}];
end
if ~isempty(swIds.interpreter)
    args = [args, {'InterpreterId', swIds.interpreter}];
end
if ~isempty(notes)
    args = [args, {'Notes', notes}];
end
if ~isempty(methodParams)
    % [Hartley settings on the inline method] (Jess Haley, 2026-10-30)
    args = [args, {'MethodParameters', methodParams}];
end
args = [args, {'Dimensions', dims}];
if ~isempty(covs)
    args = [args, {'Covariates', covs}];
end
if distributive
    args = [args, {'Fields', struct('distributive', true)}];
end
m = did2.build.statement('manipulation', entityId, 'visual stimulus', ...
    value, 'ValueKind', 'item', args{:});
m = removeEdge(m, 'time_reference_id');
m = addEdge(m, did2.convert.mintSessionDuring('marker'), presentationId);
end

function [dims, covs] = presentationAxes(n, onsets, offsets, control)
%PRESENTATIONAXES The item value's one dimension (a presentation, N of them)
%   and its covariates along it (did-schema data_body plan AMENDMENT 6): onset
%   time and offset time (seconds) when known, and the control condition
%   (logical) when a v1 control record was placed. Terms: Decided by Jess
%   Haley, 2026-10-22 [presentation dimension term] (OBI:0000807) and [onset
%   and offset terms] (EMPTY:0000368 / EMPTY:0000369), did-schema
%   V_eta_data_body_model_plan.md.
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
dims = did2.build.list(did2.build.dimension(presentationTerm(), n));
c = {};
if ~isempty(onsets)
    c{end+1} = did2.build.covariate(onsetTimeTerm(), 0, ...
        'Value', double(onsets(:)'), 'Unit', 'second');
end
if ~isempty(offsets)
    c{end+1} = did2.build.covariate(offsetTimeTerm(), 0, ...
        'Value', double(offsets(:)'), 'Unit', 'second');
end
if ~isempty(control)
    c{end+1} = did2.build.covariate(controlConditionTerm(), 0, ...
        'Logical', logical(control(:)'));
end
covs = [];
if ~isempty(c)
    covs = did2.build.list(c{:});
end
end

function t = presentationTerm()
% OBI:0000807 'presentation of stimulus' ([presentation dimension term])
t = did2.build.term('OBI:0000807', 'presentation of stimulus');
end

function t = onsetTimeTerm()
% EMPTY:0000368 'onset time' ([onset and offset terms])
t = did2.build.term('EMPTY:0000368', 'onset time');
end

function t = offsetTimeTerm()
% EMPTY:0000369 'offset time' ([onset and offset terms])
t = did2.build.term('EMPTY:0000369', 'offset time');
end

function t = controlConditionTerm()
% XCO:0000099 'control condition' ([control as covariate])
t = did2.build.term('XCO:0000099', 'control condition');
end

% ===================== the control covariate ==============================

function [control, report] = controlCovariate(records, n, trialsAreThePositions, report)
%CONTROLCOVARIATE The 'control condition' covariate's values (a 1xN logical)
%   from the presentation's v1 control_stimulus_ids RECORDS, or [] when there
%   is none to write. See CONTROL in the help above.
control = [];
records = asCell(records);
report.control_records = numel(records);
if isempty(records)
    return;
end
vectors = cell(1, numel(records));
for r = 1:numel(records)
    ids = controlEntries(records{r});
    if isempty(ids) || all(isnan(ids))
        vectors{r} = false(1, n);              % no trial was a control
        continue;
    end
    if ~trialsAreThePositions
        report.control_unfolded_reason = 'no position map';
        return;
    end
    if any(isnan(ids)) || any(ids < 1 | ids > n | ids ~= floor(ids))
        report.control_unfolded_reason = 'unmappable';
        return;
    end
    v = false(1, n);
    v(unique(ids)) = true;
    vectors{r} = v;
end
for r = 2:numel(vectors)
    if ~isequal(vectors{r}, vectors{1})
        report.control_unfolded_reason = 'conflicting';
        return;
    end
end
control = vectors{1};
report.control_records_folded = numel(records);
report.control_true = sum(control);
end

% ===================== software and the control pairing ==================

function [docs, swIds, report] = presentationSoftware(v1Body, report)
%PRESENTATIONSOFTWARE The presentation's `app` as `software` entities: the
%   program for software_id, and the run's OS and interpreter for
%   operating_system_id / interpreter_id. See SOFTWARE above.
[docs, swId, env] = ndi.migrate.internal.appSoftware(v1Body);
swIds = struct('software', swId, 'os', '', 'interpreter', '');
report.software_minted = report.software_minted + ~isempty(swId);
if report.standalone
    % an item has no software_id, operating_system_id or interpreter_id
    if ~isempty(swId)
        report.software_unreferenced = report.software_unreferenced + 1;
    end
    swIds.software = '';
    report.run_environment_unplaced = prefixed('app.', env);
    report.software_referenced = false;
    return;
end
report.software_referenced = ~isempty(swId);
sid = char(ndi.v2.sessionIdOf(v1Body));
ts = '';
if isfield(v1Body, 'base') && isfield(v1Body.base, 'datestamp'); ts = char(v1Body.base.datestamp); end
pairs = {'os', 'os_version', 'os'; 'interpreter', 'interpreter_version', 'interpreter'};
for k = 1:size(pairs, 1)
    if isfield(env, pairs{k, 1})
        [d, id] = ndi.migrate.internal.softwareEntity(env.(pairs{k, 1}), ...
            fieldOr(env, pairs{k, 2}), '', sid, ts);
        if ~isempty(id)
            docs = [docs, d]; %#ok<AGROW>
            swIds.(pairs{k, 3}) = id;
            report.run_environment_written = report.run_environment_written + 1;
            continue;
        end
    end
    % a version with no name (or no session) names no program
    for f = pairs(k, 1:2)
        if isfield(env, f{1})
            report.run_environment_unplaced{end+1} = ['app.' f{1}];
        end
    end
end
end

function [calcs, software, report] = controlCalculations(records, presentationId, ...
        entityId, nTrials, positionsAreTrials, report)
%CONTROLCALCULATIONS One `calculation` per v1 control_stimulus_ids record
%   that can be placed whole; the rest are left as v1, with the reason. See
%   CONTROL PAIRING above.
calcs = {};
software = {};
records = asCell(records);
for r = 1:numel(records)
    rec = records{r};
    recId = '';
    if isstruct(rec) && isfield(rec, 'base') && isfield(rec.base, 'id')
        recId = char(rec.base.id);
    end
    why = controlUnplaced(rec, nTrials, positionsAreTrials, report.standalone);
    if isempty(why) && isempty(recId)
        % carry-register: carry-091
        why = '[carry-091] no base.id';
    end
    if ~isempty(why)
        report.control_carried{end+1} = struct('id', recId, 'reason', why);
        continue;
    end
    [c, sw] = controlCalculation(rec, recId, presentationId, entityId, nTrials, ...
        report.distributive);
    calcs{end+1} = c; %#ok<AGROW>
    software = [software, sw]; %#ok<AGROW>
    report.control_converted_ids{end+1} = recId;
end
report.control_calculations = numel(calcs);
end

function why = controlUnplaced(rec, nTrials, positionsAreTrials, standalone)
%CONTROLUNPLACED Why this record cannot be written whole as a calculation;
%   '' when it can ([generic stage is lossless]).
%   Decided by Jess Haley, 2026-10-27 [control record fields split] ("Q5
%   yes", did-schema V_eta_go_forward_class_audit.md): "a field outside NDI's
%   template is carried under carry-100 (malformed); `app` fields beyond
%   name/version/url/os/interpreter go to the `software` entity, as
%   [presentation app is software]; carry-089 keeps only template fields with
%   no home". NDI's template here is what its writer writes
%   (+ndi/+app/+stimulus/tuning_response.m control_stimulus at the locked
%   main: control_stimulus_ids.json's block {control_stimulus_ids,
%   control_stimulus_id_method} plus ndi.app's newdocument `app` block {name,
%   version, url, os, os_version, interpreter, interpreter_version}, and the
%   `stimulus_presentation_id` edge). So a block field beside the two, an
%   `app` field outside those seven, and an edge other than
%   stimulus_presentation_id / session_id are carry-100. The record is read
%   as raw v1: DID-matlab #351 deleted did2.convert.universalRenames, so the
%   app_name / app_version / app_url spellings it wrote are fields outside the
%   app template like any other ([rename clashes are malformed], Jess Haley,
%   2026-11-01). The two app fields
%   beyond the five, os_version and interpreter_version, already go to the
%   software entities (the OS and interpreter, each with its version:
%   controlCalculation). Every template field now has a home, so no site
%   here cites carry-089.
why = '';
if standalone
    % carry-register: carry-090
    why = '[carry-090] no subject: the presentation is a standalone item';
    return;
end
if ~positionsAreTrials
    % carry-register: carry-090
    why = '[carry-090] the presentation is a frame sequence, not trials';
    return;
end
if isempty(char(ndi.v2.sessionIdOf(rec)))
    % carry-register: carry-091
    why = '[carry-091] no session';
    return;
end
raw = [];
if isfield(rec, 'control_stimulus_ids') && isstruct(rec.control_stimulus_ids)
    blk = rec.control_stimulus_ids;
    other = setdiff(fieldnames(blk), {'control_stimulus_ids', 'control_stimulus_id_method'});
    for k = 1:numel(other)
        if ~isempty(blk.(other{k}))
            % carry-register: carry-100
            why = ['[carry-100] a field outside the control_stimulus_ids template: ' ...
                'control_stimulus_ids.' other{k}];
            return;
        end
    end
    if isfield(blk, 'control_stimulus_ids')
        raw = blk.control_stimulus_ids;
    end
    if isfield(blk, 'control_stimulus_id_method') && ~isempty(blk.control_stimulus_id_method) ...
            && ~(isstruct(blk.control_stimulus_id_method) && isscalar(blk.control_stimulus_id_method))
        % carry-register: carry-091
        why = '[carry-091] control_stimulus_id_method is not a block';
        return;
    end
end
% Decided by Jess Haley, 2026-10-26 [NaN control means no control]
% (did-schema V_eta_go_forward_class_audit.md): NaN is NDI's writer's value
% for a trial with no control (tuning_response.m writes it; its reader skips
% it), so a NaN entry is converted -- the calculation records NaN for that
% trial -- and only an empty, non-numeric or infinite entry is malformed.
if iscell(raw) || ~isnumeric(raw) || isempty(raw) || any(isinf(double(raw(:))))
    % carry-register: carry-091
    why = '[carry-091] the pairing is empty, not numeric, or infinite';
    return;
end
ids = double(raw(:)');
if numel(ids) ~= nTrials
    % carry-register: carry-091
    why = sprintf('[carry-091] %d pairing entr(ies) for %d trial(s)', numel(ids), nTrials);
    return;
end
paired = ids(~isnan(ids));
if any(paired < 1 | paired > nTrials | paired ~= floor(paired))
    % carry-register: carry-091
    why = '[carry-091] an entry is not a trial number of the presentation';
    return;
end
if isfield(rec, 'app') && ~isempty(rec.app)
    if ~(isstruct(rec.app) && isscalar(rec.app))
        % carry-register: carry-091
        why = '[carry-091] app is not a block';
        return;
    end
    known = appTemplateFields();
    fn = fieldnames(rec.app);
    for k = 1:numel(fn)
        v = rec.app.(fn{k});
        if isempty(v); continue; end
        if ~any(strcmp(fn{k}, known))
            % carry-register: carry-100
            why = ['[carry-100] a field outside the app template: app.' fn{k}];
            return;
        end
        if ~(ischar(v) || (isstring(v) && isscalar(v)))
            % carry-register: carry-091
            why = ['[carry-091] app.' fn{k} ' is not text'];
            return;
        end
    end
    [~, swId] = ndi.migrate.internal.appSoftware(rec);
    if isempty(swId) && any(cellfun(@(f) ~isempty(rec.app.(f)), fn))
        % carry-register: carry-091
        why = '[carry-091] the app names no program';
        return;
    end
    [~, ~, env] = ndi.migrate.internal.appSoftware(rec);
    if (isfield(env, 'os_version') && ~isfield(env, 'os')) ...
            || (isfield(env, 'interpreter_version') && ~isfield(env, 'interpreter'))
        % carry-register: carry-091
        why = '[carry-091] an OS or interpreter version with no name';
        return;
    end
end
if isfield(rec, 'depends_on') && ~isempty(rec.depends_on)
    deps = rec.depends_on;
    if isstruct(deps); deps = num2cell(deps); end
    for k = 1:numel(deps)
        d = deps{k};
        if ~isstruct(d) || ~isfield(d, 'name'); continue; end
        if any(strcmp(char(d.name), {'stimulus_presentation_id', 'session_id'})); continue; end
        v = '';
        for f = {'value', 'document_id'}
            if isfield(d, f{1}) && ~isempty(d.(f{1})); v = d.(f{1}); end
        end
        if ~isempty(v)
            % carry-register: carry-100
            why = ['[carry-100] an edge outside the control_stimulus_ids template: ' char(d.name)];
            return;
        end
    end
end
end

function [c, software] = controlCalculation(rec, recId, presentationId, entityId, ...
        nTrials, distributive)
%CONTROLCALCULATION The calculation for one placeable record (CONTROL PAIRING).
sid = char(ndi.v2.sessionIdOf(rec));
ts = '';
if isfield(rec.base, 'datestamp'); ts = char(rec.base.datestamp); end
[software, swId, env] = ndi.migrate.internal.appSoftware(rec);
osId = '';
interpreterId = '';
if isfield(env, 'os')
    [d, osId] = ndi.migrate.internal.softwareEntity(env.os, ...
        fieldOr(env, 'os_version'), '', sid, ts);
    software = [software, d];
end
if isfield(env, 'interpreter')
    [d, interpreterId] = ndi.migrate.internal.softwareEntity(env.interpreter, ...
        fieldOr(env, 'interpreter_version'), '', sid, ts);
    software = [software, d];
end
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
params = {};
blk = rec.control_stimulus_ids;
if isfield(blk, 'control_stimulus_id_method') && isstruct(blk.control_stimulus_id_method)
    rule = blk.control_stimulus_id_method;
    fn = fieldnames(rule);
    for k = 1:numel(fn)
        if isempty(rule.(fn{k})); continue; end
        % the rule verbatim: its v1 field name is the variable (a label)
        params{end+1} = methodParameter(fn{k}, rule.(fn{k})); %#ok<AGROW>
    end
end
ids = double(blk.control_stimulus_ids(:)');
standIn = [recId '_time_reference_pending'];
args = {'Method', 'control stimulus pairing', ...
    'InputIds', {presentationId}, ...
    'TimeReferenceIds', {standIn}, ...
    'Dimensions', did2.build.list(did2.build.dimension(presentationTerm(), nTrials)), ...
    'Notes', ['Per presented trial, the 0-based position (along the ' ...
        'presentation of stimulus dimension) of the control trial NDI''s ' ...
        'tuning_response paired it with (v1 control_stimulus_ids).'], ...
    'SessionId', sid, 'Id', recId, 'CreationTimestamp', ts, 'Validate', false};
if ~isempty(params)
    args = [args, {'MethodParameters', did2.build.list(params{:})}];
end
if ~isempty(swId);          args = [args, {'SoftwareId', swId}]; end
if ~isempty(osId);          args = [args, {'OperatingSystemId', osId}]; end
if ~isempty(interpreterId); args = [args, {'InterpreterId', interpreterId}]; end
if distributive
    args = [args, {'Fields', struct('distributive', true)}];
end
c = did2.build.statement('calculation', entityId, 'control trial', ...
    did2.build.valueCell('count', ids - 1), 'ValueKind', 'count', args{:});
c = removeEdge(c, 'time_reference_id');
c = addEdge(c, did2.convert.mintSessionDuring('marker'), recId);
end

function p = methodParameter(label, v)
% One value form, read from the value (stimulusRecipe's addAuto rule).
if ischar(v) || (isstring(v) && isscalar(v))
    p = did2.build.parameter(label, 'Text', char(v));
elseif islogical(v)
    p = did2.build.parameter(label, 'Count', double(v(1)));
elseif isnumeric(v) && isscalar(v)
    p = did2.build.parameter(label, 'Value', double(v));
elseif isnumeric(v)
    p = did2.build.parameter(label, 'Matrix', double(v(:)'));
else
    p = did2.build.parameter(label, 'Text', jsonencode(v));
end
end

function v = fieldOr(s, name)
v = '';
if isfield(s, name); v = s.(name); end
end

function names = prefixed(prefix, s)
names = cellfun(@(f) [prefix f], reshape(fieldnames(s), 1, []), 'UniformOutput', false);
end

function ids = controlEntries(v1Control)
ids = [];
if isstruct(v1Control) && isfield(v1Control, 'control_stimulus_ids') ...
        && isstruct(v1Control.control_stimulus_ids) ...
        && isfield(v1Control.control_stimulus_ids, 'control_stimulus_ids')
    ids = v1Control.control_stimulus_ids.control_stimulus_ids;
end
if iscell(ids)
    ids = cellfun(@(x) firstNumber(x), ids);
end
ids = double(ids(:)');
end

function x = firstNumber(x)
if isempty(x) || ~isnumeric(x)
    x = NaN;
else
    x = double(x(1));
end
end

function c = asCell(x)
if isempty(x)
    c = {};
elseif iscell(x)
    c = reshape(x, 1, []);
elseif isstruct(x)
    c = reshape(num2cell(x), 1, []);
else
    c = {};
end
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
    'timing_file',         'not declared', ...
    'timing_file_entries', 0, ...
    'timing_clocktype',    '', ...
    'files_attached',      0, ...
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
    'trial_positions',     [], ...
    'control_records',     0, ...
    'control_records_folded', 0, ...
    'control_true',        0, ...
    'control_unfolded_reason', '', ...
    'control_calculations', 0, ...
    'control_converted_ids', {{}}, ...
    'control_carried',     {{}}, ...
    'software_minted',     0, ...
    'software_referenced', false, ...
    'software_unreferenced', 0, ...
    'run_environment_written', 0, ...
    'run_environment_unplaced', {{}}, ...
    'flashed_bars',        0, ...
    'uniform_fields_kept', 0, ...
    'shape_movie_note',    false, ...
    'hartley_without_enumeration', false, ...
    'hartley_own_parameters', 0, ...
    'notes_not_written_standalone', false, ...
    'entity_id',           '', ...
    'unplaced_fields',     {{}}, ...
    'reason',              '');
end

% ===================== v1 readers =========================================

function names = appTemplateFields()
%APPTEMPLATEFIELDS The `app` block's fields: NDI's app.json at the locked
%   NDI-matlab main, which ndi.app's newdocument writes.
names = {'name', 'version', 'url', 'os', 'os_version', 'interpreter', ...
    'interpreter_version'};
end

function outside = appFieldsOutsideTemplate(body)
%APPFIELDSOUTSIDETEMPLATE The non-empty `app` fields of BODY outside NDI's
%   app template, as 'app.<field>' (a row cell; carry-100).
outside = {};
if ~isfield(body, 'app') || ~isstruct(body.app) || ~isscalar(body.app)
    return;
end
fn = setdiff(fieldnames(body.app), appTemplateFields(), 'stable');
for k = 1:numel(fn)
    if ~isempty(body.app.(fn{k}))
        outside{end+1} = ['app.' fn{k}]; %#ok<AGROW>
    end
end
end

function [outside, unplaced, generator] = unplacedPresentationFields(block, stimuli, kinds, hartleyRoute)
%UNPLACEDPRESENTATIONFIELDS The v1 fields of one presentation the
%   decomposition would not write ([generic stage is lossless], Jess Haley,
%   2026-10-25). Field names, de-duplicated, in a stable order.
%   OUTSIDE  fields outside NDI's stimulus_presentation template (a block
%            field beside stimuli / presentation_order / presentation_time, a
%            stimulus field beside `parameters`): carry-100, [unread
%            stimulus parameters are method parameters] (Jess Haley,
%            2026-10-27).
%   UNPLACED `parameters` keys with no home decided: a second value of a
%            key the Hartley basis or gratingRecipe reads one of (and an
%            imageType other than 1 or 2, which newStimKind never calls a
%            grating). Every other unread key is a method parameter entry
%            ([unread stimulus parameters are method parameters],
%            ndi.migrate.internal.stimulusRecipe), so it is not listed.
%   GENERATOR on the Hartley route, the generator keys the shared basis does
%            not read: the manipulation's inline method parameters
%            ([Hartley settings on the inline method], Jess Haley,
%            2026-10-30), unplaced only for a standalone item.
outside = {};
unplaced = {};
generator = {};
if isstruct(block)
    other = setdiff(fieldnames(block), {'stimuli', 'presentation_order', 'presentation_time'});
    for k = 1:numel(other)
        if ~isempty(block.(other{k}))
            outside{end+1} = ['stimulus_presentation.' other{k}]; %#ok<AGROW>
        end
    end
    if isfield(block, 'stimuli')
        raw = block.stimuli;
        if isstruct(raw); raw = num2cell(raw); end
        if iscell(raw)
            for k = 1:numel(raw)
                if ~isstruct(raw{k}); continue; end
                other = setdiff(fieldnames(raw{k}), {'parameters'});
                for j = 1:numel(other)
                    if ~isempty(raw{k}.(other{j}))
                        outside{end+1} = ['stimuli.' other{j}]; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
gratingRead = {'angle', 'orientation', 'sFrequency', 'spatial_frequency', 'sf', ...
    'tFrequency', 'temporal_frequency', 'tf', 'contrast', 'imageType'};
hartleyRead = hartleyReads();
blankNames = {'isblank', 'is_blank', 'blank'};
for i = 1:numel(stimuli)
    p = stimParameters(stimuli, i);
    fn = fieldnames(p);
    if hartleyRoute
        read = hartleyRead;
    elseif strcmp(kinds{i}, 'grating')
        read = gratingRead;
    else
        continue;   % a blank and every other kind: every parameter is an entry (stimulusRecipe)
    end
    for k = 1:numel(fn)
        v = p.(fn{k});
        if isempty(v) || any(strcmp(fn{k}, blankNames)); continue; end
        if ~any(strcmp(fn{k}, read))
            if hartleyRoute
                generator{end+1} = ['parameters.' fn{k}]; %#ok<AGROW>
            end
            % a grating: an entry on its method (gratingOrBlank, stimulusRecipe)
        elseif isnumeric(v) && numel(v) > 1
            unplaced{end+1} = ['parameters.' fn{k} ' (more than one value)']; %#ok<AGROW>
        elseif ~hartleyRoute && strcmp(fn{k}, 'imageType') ...
                && ~(isnumeric(v) && isscalar(v) && any(v == [1 2]))
            unplaced{end+1} = 'parameters.imageType'; %#ok<AGROW>
        end
    end
end
% rows, so the two lists concatenate (unique gives a column for an empty cell)
outside = reshape(unique(outside, 'stable'), 1, []);
unplaced = reshape(unique(unplaced, 'stable'), 1, []);
generator = reshape(unique(generator, 'stable'), 1, []);
end

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
