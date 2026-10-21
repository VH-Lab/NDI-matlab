function [manipBody, gratingBodies, bodyDoc, records, report, extraBodies] = ...
        stimulusPresentationToTimedSequence(v1Body, resolver, targetVersion, sequence)
%STIMULUSPRESENTATIONTOTIMEDSEQUENCE Assemble the SIGNED stimulus model from a
%   legacy stimulus_presentation: N deduped standalone `visual_grating`
%   documents + ONE `timed_sequence_manipulation` that references them, its
%   playlist an index array into those references, and (only when the source
%   really carries per-trial times) a `sampled_body` whose irregular time axis
%   is the trial onsets.
%
%   AUTHORISED BY TWO SIGNATURES in DID-schema
%   `schemas/V_eta_stimulus_model_plan.md`:
%     :224 (2026-08-08)  `timed_sequence` + `timed_sequence_manipulation`;
%                        stimulus_presentation is DECOMPOSED around its
%                        preserved id, not dissolved.
%     end of file (2026-08-17)  a stimulus_presentation carrying a SEQUENCE of
%                        visual gratings becomes ONE timed_sequence_manipulation
%                        referencing N visual_grating documents;
%                        `visual_grating_manipulation` is RETAINED for the
%                        genuine single-grating, presentation-less case.
%
%   ========================================================================
%   STATUS: WIRED, 2026-08-17. THE TWO BLOCKERS RECORDED HERE ARE BOTH
%   CLEARED, AND THE RESOLUTION OF EACH IS KEPT so a reader does not go
%   looking for a decision that has already been made.
%   ========================================================================
%
%   (1) THE id COLLISION IS GONE, BECAUSE THE TWO PASSES ARE NOW MUTUALLY
%       EXCLUSIVE BY DEFINITION. The 2026-08-17 signature RETAINS
%       `visual_grating_manipulation` for the PRESENTATION-LESS single-grating
%       case -- "not a rival model to retire, the degenerate one". A
%       presentation is either a sequence (this function) or absent (that
%       one), so only one document can ever claim the presentation id. The
%       flattening pass is gated OFF in ndi.migrate.local accordingly.
%
%       AND THE CONSEQUENCE IS NOT PAPERED OVER: that pass structurally
%       requires a presentation (`if ~isPresentationBody(b); continue`), so
%       gating it to the presentation-less case means it stops firing
%       ENTIRELY, and the retained single-grating case has NO EMITTER TODAY.
%       No v1 class carries a lone grating -- `stimulus_presentation` is the
%       only carrier of grating parameters in the did_v1 universe -- so
%       nothing is stranded by this today. It is recorded as an open item
%       rather than filled with an invented source class.
%
%       The SEQUENCING condition the signature set is met rather than waived:
%       `+migrators_j/control_stimulus_ids.m` writes a POPULATED
%       `timed_sequence_id` equal to the presentation id, and this function
%       PRESERVES that id on the manipulation, so the edge resolves to the
%       new document instead of dangling.
%
%   (2) `visual_grating` IS NO LONGER ABSTRACT. The flag was removed by team
%       decision on 2026-08-17 (DID-schema 744149b, "visual_grating stops
%       being abstract"), as it had been for `timed_sequence` the same day,
%       so the N standalone documents this function builds can be
%       instantiated. Both classes now read `abstract=<absent>`.
%
%   THE SAME DAY, `visual_grating` GAINED TWO FIELDS THIS EMITTER USES
%   (DID-schema 7abb2d3): `value.phase` and `value.source_geometry`. They are
%   populated on the Hartley path -- see
%   ndi.migrate.internal.hartleyBasisGratings, which explains why the phase is
%   load-bearing (without it the 3360 basis functions dedup to 1680) and why
%   the degree-domain fields are deliberately left unset.
%
%   WHAT IT EMITS, per input stimulus_presentation
%   ------------------------------------------------------------------------
%     gratingBodies  N standalone `visual_grating` documents, one per DISTINCT
%                    grating value, deduped by the value content itself (the
%                    eight typed fields), built with
%                    ndi.migrate.internal.gratingValueFromParameters -- the
%                    same mapper the flattening pass uses. New ids: these are
%                    new documents, nothing in v1 references a single stimulus.
%     manipBody      ONE `timed_sequence_manipulation`, base.id = THE V1
%                    PRESENTATION id, so `stimulus_response.
%                    stimulus_presentation_id`, `hartley_calc.
%                    stimulus_presentation_id` and `control_stimulus_ids.
%                    stimulus_presentation_id` keep resolving. Measured on the
%                    20211116 corpus: 494 inbound edges onto 11 presentation
%                    ids (273 + 210 + 11).
%                      depends_on subject_id       the animal (REQUIRED)
%                                 instrument_id    the stimulator, from v1
%                                                  `stimulus_element_id` (T7)
%                                 presented_id_1..N  the distinct gratings
%                      timed_sequence.value.presentation_order
%                                 the v1 playlist REMAPPED onto the distinct
%                                 set (v1 indexes `stimuli`, which is not
%                                 deduped; the signed encoding indexes the
%                                 refs, which is)
%     bodyDoc        a `sampled_body` -- ONLY when the source carries a real
%                    per-trial onset AND offset for every trial. See TIMING.
%
%     records        the per-trial durations, [nTrials x 1], for the caller to
%                    serialise into the body payload (the same contract
%                    stimulusPresentationToManipulation uses for its matrix).
%
%     extraBodies    always {}. It carried the N-copy multi-subject shape,
%                    which Jess Haley retired on 2026-10-21 (see SEVERAL
%                    ANIMALS); kept as an output so callers do not change.
%
%   SEVERAL ANIMALS (Jess Haley, 2026-10-21)
%   ------------------------------------------------------------------------
%   A presentation that resolves to several animals in its session, by any
%   route (stimulus_response, the session-scoped epoch, the stimulator), is
%   neither refused as ambiguous nor written as N per-animal copies. The
%   decided shape is ONE cohort entity per session -- the animals recorded
%   together, each member_of it, with a stable id -- and ONE manipulation of
%   the cohort with `distributive` true; a single-animal presentation still
%   names its animal. This pass writes the did-schema the NDI e2e workflows
%   pin (v_eta-pre73), and its subject_statement declares no `distributive`,
%   so the cohort shape cannot be written here: such a presentation is left as
%   v1 with the reason from severalAnimals and counted in
%   `report.several_animals` (the number of animals). The storage_mode
%   `reference` N-copy shape that this header described before is gone.
%
%   SCOPE, AND THE FOURTH ARGUMENT
%   ------------------------------------------------------------------------
%   The 2026-08-17 signature covers a presentation carrying a SEQUENCE OF
%   VISUAL GRATINGS, and not every v1 presentation ENUMERATES one. On 20211116
%   only 224 of 235 stimuli are gratings; 10 are a Hartley GENERATOR spec (M,
%   K_absmax, L_absmax, sfmax, randState) that enumerates nothing, and 1 is the
%   blank. A presentation holding any stimulus the mapper cannot type is
%   REFUSED rather than mapped to zeros -- see the guard below for the
%   measurement and the reasoning.
%
%   SEQUENCE (optional, 4th) supplies that missing enumeration from elsewhere:
%     .presented_ids  cell of ALREADY-MINTED stimulus document ids
%     .order          [1 x nFrames] index into presented_ids, per frame
%     .frame_times    [1 x nFrames] frame onsets, seconds (optional)
%   When it is given, the refusal above does not apply -- the playlist and the
%   refs come from SEQUENCE and the presentation's own `stimuli` block is read
%   only for its denominators. ndi.migrate.internal.hartleyBasisGratings builds
%   it from the `hartley_calc` documents that reference the presentation.
%
%   TIMING, AND WHY THE BODY IS USUALLY ABSENT
%   ------------------------------------------------------------------------
%   The v1 TEMPLATE declares `stimulus_presentation.presentation_time` inline.
%   THE WRITER DOES NOT WRITE IT, and where template and writer disagree the
%   writer wins. `+ndi/+app/+stimulus/decoder.m:132-134` on origin/main:
%
%       stimulus_presentation = struct('presentation_order', data.stimid(:),...
%           ... % 'presentation_time', presentation_time, ... % we now put this in a file
%           'stimuli', mystim);
%       ...
%       nd = nd.add_file('presentation_time.bin', presentation_time_filename);
%
%   and its reader calls the inline form "old way" with a deprecation warning
%   (decoder.m:154-156). Measured over the 20211116 corpus: 11 of 11
%   stimulus_presentation documents carry block keys {presentation_order,
%   stimuli} and NO `presentation_time`, and 11 of 11 carry
%   `files.file_list = {'presentation_time.bin'}`.
%
%   A batch post-pass reads decoded STRUCT bodies; it does not open attached
%   binaries. So on real data the onsets are not reachable here, and this
%   function emits NO sampled_body rather than an axis of zeros. That
%   difference is deliberate: on the same corpus the flattening pass's
%   `trialField` helper falls through to 0 for every trial, so its
%   `axes(1).values` is a vector of zeros presented as measured onsets. "Nobody
%   looked" is not "it happened at t=0".
%
%   `stimopen` / `stimclose` / `stimevents` are NOT carried. `stimevents` stays
%   untyped by gate 4 of the 2026-08-08 signature ("until someone reads real
%   ones"); the other two have nowhere to land in the signed axis shape and
%   inventing a slot for them here would pre-empt that read.
%
%   NOT CARRIED, DELIBERATELY: the time anchor. The signed shape wants
%   `time_reference_# -> relative_reference -> epoch`. It is an OPTIONAL edge
%   (`subject_interaction` declares `time_reference_#` with mustBeNonEmpty
%   false), the epoch anchor needs a `clocktype` that lives in the same
%   unreadable file as the onsets, and minting a placeholder with a guessed
%   clock is the invented-empty-edge pattern with extra steps. The v1
%   `epochid.epochid` string is reported instead, so a later pass can anchor
%   it from evidence.
%
%   Returns [] for manipBody/bodyDoc and a report carrying `reason` when
%   nothing can be assembled; the caller then leaves the presentation as-is.
%
%   See also: ndi.migrate.internal.gratingValueFromParameters,
%   ndi.migrate.internal.hartleyBasisGratings (the supplied enumeration),
%   ndi.migrate.internal.stimulusPresentationToManipulation (RETAINED for the
%   presentation-less single-grating case, and gated off in ndi.migrate.local
%   because no v1 document is in that case),
%   ndi.migrate.internal.bodyResolver (subjectsForPresentation).

arguments
    v1Body   (1,1) struct
    resolver (1,1) struct
    targetVersion (1,:) char = 'V_eta'
    sequence = []
end

manipBody = []; gratingBodies = {}; bodyDoc = []; records = [];
% extraBodies: always {} (the N-copy shape was retired 2026-10-21).
extraBodies = {};

% Rule 5: the report's denominators exist before any early return, so a
% refusal prints the same SHAPE as a success and "fell through" is never
% inferable only by subtracting two other counters.
report = newReport();

presentationId = baseField(v1Body, 'id', '');
sessionId      = ndi.v2.sessionIdOf(v1Body);
datestamp      = baseField(v1Body, 'datestamp', '');
report.epoch_id = epochIdOf(v1Body);

% --- the guards that would otherwise QUARANTINE ------------------------------
% `base` declares id / session_id / creation_timestamp mustBeNonEmpty, so a
% document missing any of them is a guaranteed validation failure. Refuse and
% count it; a passthrough is a non-gating outcome and a quarantine is not.
if isempty(presentationId) || isempty(sessionId) || isempty(datestamp)
    report.reason = 'base id / session_id / datestamp incomplete';
    return;
end

% --- WHAT KIND OF STIMULUS EACH ONE IS (NewStim class recogniser) -------------
% Classified BEFORE the animal is resolved, so the per-kind counts are reported
% for every presentation, including the ones refused for having no animal. The
% classification is used again by the grating guard below.
earlyBlock = struct();
if isfield(v1Body, 'stimulus_presentation') && isstruct(v1Body.stimulus_presentation)
    earlyBlock = v1Body.stimulus_presentation;
end
earlyStimuli = stimulusArray(earlyBlock);
stimulusKinds = cell(1, numel(earlyStimuli));
for i = 1:numel(earlyStimuli)
    stimulusKinds{i} = newStimKind(stimParameters(earlyStimuli, i));
    report.stimulus_kinds.(stimulusKinds{i}) = ...
        report.stimulus_kinds.(stimulusKinds{i}) + 1;
end

% subject_id is mustBeNonEmpty on subject_statement and RequiredDependencies is
% armed by default (+did2/+schema/cache.m), so no animal means no manipulation.
animals = resolver.subjectsForPresentation(presentationId);
report.subjects_resolved = numel(animals);
report.animal_source = 'response';
if numel(animals) > 1
    % SEVERAL ANIMALS (Jess Haley, 2026-10-21): not refused as ambiguous and
    % not N copies. The decided shape is ONE cohort entity per session (the
    % animals recorded together, each member_of it, a stable id) and ONE
    % manipulation of the cohort with `distributive` true. This pass writes the
    % did-schema the NDI e2e pins (v_eta-pre73), whose subject_statement has no
    % `distributive`, so the shape cannot be written here: pass through, count.
    [report.several_animals, report.reason] = severalAnimals(numel(animals), 'stimulus_response');
    report.animal_source = 'none';
    return;
end
if isempty(animals)
    % FORK 1 (team call 2026-08-22): a presentation with NO stimulus_response
    % linking it to a responding element -- the non-tuning case, e.g. an
    % opto/bath ephys experiment that computes no per-stimulus response -- is
    % still attributed to the animal RECORDED IN ITS OWN EPOCH. Session-scoped,
    % because a v1 epoch id is a NAME that repeats across sessions and the bare
    % map pools them. Measured on Dab (run #4, 1242 refused): 1174 resolve to
    % exactly one subject, 0 to several, 68 to none.
    %
    % THE 68 ARE NOT SESSION-ID GAPS. This comment used to call them "all
    % session-id gaps", on the evidence that each epoch NAME records an element
    % in some other session. That evidence does not show a gap: v1 epoch names
    % (t000NN) repeat across animals, and a cross-session search finds 2-12
    % different subjects for every one of the 68 and the true animal for none.
    % Read on the Dab corpus 2026-10-21: each of the 68 (session, epoch) pairs
    % holds 1 stimulus_presentation, 2 daqreader_mfdaq_epochdata_ingested and 1
    % daqmetadatareader_epochdata_ingested -- raw ephys WAS recorded (median
    % epoch 347 s) -- and no element_epoch, because Dab writes element_epoch
    % only for SORTED units and these are epochs where no unit was assigned.
    % Fork 1 reaches the animal only through a sorted unit, so it finds none.
    scoped = resolver.subjectsViaEpochScoped(presentationId);
    if numel(scoped) == 1
        animals = scoped;
        report.animal_source = 'epoch';
    elseif numel(scoped) > 1
        report.animal_source = 'none';
        [report.several_animals, report.reason] = severalAnimals(numel(scoped), 'epoch');
        return;
    else
        report.animal_source = 'none';
        nEl = resolver.epochElementCountScoped(presentationId);
        if nEl > 0
            report.reason = sprintf(['no responding animal; the epoch''s %d ' ...
                'recorded element(s) resolve to no subject'], nEl);
            return;
        end
        % THE STIMULATOR ROUTE (Jess Haley, 2026-10-21, NDI-matlab PR #1021).
        % The epoch records no element in this session, so follow the
        % presentation's own `stimulus_element_id` edge to the stimulator
        % element and take that element's v1 subject, through the same
        % element -> subject resolution used everywhere else
        % (bodyResolver.subjectOfElement). Session-scoped. On Dab it resolves
        % all 68 to a real subject and agrees with fork 1 on 1174/1174 of the
        % presentations fork 1 does attribute. Exactly one subject, or refuse.
        viaStimulator = resolver.subjectsViaStimulator(presentationId);
        report.stimulator_subjects = numel(viaStimulator);
        if numel(viaStimulator) == 1
            animals = viaStimulator;
            report.animal_source = 'stimulator';
        elseif numel(viaStimulator) > 1
            [report.several_animals, report.reason] = ...
                severalAnimals(numel(viaStimulator), 'stimulator');
            return;
        else
            % Neither the epoch nor the stimulator names an animal. Split the
            % residual by whether the epoch NAME records elements in another
            % session -- a measurement only: a positive count is NOT evidence
            % of a session-id gap (see above).
            nAny = resolver.epochElementCountUnscoped(presentationId);
            if nAny > 0
                % FORK 2 -- MEASURED AND DISARMED (2026-08-25). It was armed and
                % run on Dab (e2e 32868824054): all 68 such presentations
                % resolved to 2-12 sibling subjects, NONE to exactly one --
                % epoch-name collisions across animals, and the true animal in
                % 0 of 68. Cross-session ATTRIBUTION stays disarmed. The
                % sibling-subject COUNT is still measured and reported, so a
                % future corpus with a clean one-subject case is visible in the
                % histogram rather than silently folded on an unproven premise.
                % See bodyResolver.subjectsViaEpochSibling.
                sibling = resolver.subjectsViaEpochSibling(presentationId);
                report.sibling_subjects = numel(sibling);
                if numel(sibling) == 1
                    report.reason = ['no responding animal; the epoch records ' ...
                        'no element in THIS session, the stimulator element ' ...
                        'names no subject, and exactly one sibling session ' ...
                        'carries the epoch name -- fork 2 attribution is ' ...
                        'DISARMED (team call)'];
                elseif numel(sibling) > 1
                    report.reason = sprintf(['no responding animal; the ' ...
                        'stimulator element names no subject, and the epoch ' ...
                        'name records only in sibling session(s), resolving ' ...
                        'to %d subjects -- ambiguous across sessions'], ...
                        numel(sibling));
                else
                    report.reason = ['no responding animal; the stimulator ' ...
                        'element names no subject, and the epoch name records ' ...
                        'in a sibling session, but no element there resolves ' ...
                        'to a subject'];
                end
                return;
            else
                report.reason = ['no responding animal; the epoch has no ' ...
                    'recorded element in any session and the stimulator ' ...
                    'element names no subject'];
                return;
            end
        end
    end
end
animalId = animals{1};

stimulatorId = depValue(v1Body, 'stimulus_element_id');
report.instrument_resolved = ~isempty(stimulatorId);

% --- read the presentation ---------------------------------------------------
block = struct();
if isfield(v1Body, 'stimulus_presentation') && isstruct(v1Body.stimulus_presentation)
    block = v1Body.stimulus_presentation;
end

stimuli = stimulusArray(block);
order   = orderVector(block);
report.stimuli_read = numel(stimuli);
report.trials       = numel(order);

if isempty(stimuli) || isempty(order)
    report.reason = 'no stimuli / no presentation_order';
    return;
end

% --- THE SUPPLIED-SEQUENCE PATH: the enumeration lives in another document ---
% Ten of the eleven 20211116 presentations carry a GENERATOR RECIPE, not a
% list: one stimulus whose parameters are (M, K_absmax, L_absmax, sfmax, fps,
% randState). Nothing in the document enumerates the basis, so the guards
% below correctly refuse it -- and the enumeration is not lost, it is in the
% `hartley_calc` documents that reference this presentation
% (`hartley_reverse_correlation.hartley_numbers`, 3360 entries, identical
% across all 210 of them) together with a `frameTimes` of the same length.
% ndi.migrate.internal.hartleyBasisGratings reads that half, mints the basis
% ONCE for the whole session, and hands the result in here.
%
% WHY THE REFS ARE MINTED BY THE CALLER AND NOT HERE: the basis is a property
% of the SESSION, not of one presentation. All ten presentations play the same
% 3360 basis functions, so minting per presentation would create 33,600
% documents describing 3,360 distinct gratings.
if ~isempty(sequence)
    [presentedIds, presentationOrder, frameTimes, why] = readSequence(sequence);
    report.basis_source = 'supplied enumeration (hartley_calc)';
    report.shared_refs  = numel(presentedIds);
    report.frames       = numel(presentationOrder);
    if ~isempty(why)
        report.reason = why;
        report.basis_source = 'not read';
        report.shared_refs = 0;
        report.frames = 0;
        return;
    end
    manipBody = manipulationBody(presentationId, sessionId, datestamp, ...
        animalId, stimulatorId, presentedIds, presentationOrder, targetVersion);
    % THE AXIS GOES ON THE STATEMENT, NOT ON A BODY, and the rule is "axes
    % live where the payload lives". The signed data_body decision mounts
    % `axes[]` on `subject_statement` when storage_mode is `inline` and on
    % `sampled_body` when it is `body`, mutually exclusive. Here there are no
    % bytes to store: the playlist is inline in `timed_sequence.value` and the
    % frame onsets are the axis itself. The deprecated-inline-timing path
    % below DOES have a payload (one duration per trial), which is why it
    % emits a body and this does not.
    %
    % AND THIS RECOVERS TIMING THAT IS OTHERWISE LOST. The writer moved
    % `presentation_time` into `presentation_time.bin` -- declared by 11 of 11
    % presentations in this corpus and present in 0 of them -- so `frameTimes`
    % is the only surviving stimulus timing on this data.
    if ~isempty(frameTimes)
        timeAxis = axisEntry(struct('node', '', 'name', 'time'), numel(frameTimes));
        timeAxis.regular     = false;
        timeAxis.source_unit = 's';
        timeAxis.values = struct('values', {frameTimes}, ...
            'source_values', {frameTimes});
        manipBody.subject_statement.axes = timeAxis;
        report.trials_with_timing = numel(frameTimes);
        report.timing_source = 'frameTimes (hartley_calc)';
    end
    return;
end

% v1 `presentation_order` indexes `stimuli` 1-based (measured on 20211116: the
% 225-stimulus run's order runs 1..225 over 675 trials). An index outside that
% range indexes nothing, and quietly dropping those trials would shorten a
% playlist without saying so -- refuse the document instead.
outOfRange = sum(order < 1 | order > numel(stimuli) | order ~= floor(order));
report.trials_out_of_range = outOfRange;
if outOfRange > 0
    report.reason = 'presentation_order indexes outside the stimuli list';
    return;
end

% --- IN SCOPE? the signature covers a SEQUENCE OF VISUAL GRATINGS ------------
% Not every v1 `stimuli(i).parameters` describes a grating, and the difference
% is not cosmetic. Measured over the 20211116 corpus -- 11 documents, 235
% stimuli, three distinct parameter key signatures:
%
%     224  angle animType backdrop background barColor barWidth chromhigh
%          chromlow contrast dispprefs distance fixedDur flickerType imageType
%          loops nCycles nSmoothPixels phaseSequence phaseSteps rect
%          sFrequency sPhaseShift tFrequency windowShape      <- gratings
%      10  K_absmax L_absmax M backdrop background chromhigh chromlow contrast
%          dispprefs distance fps randState rect reps sfmax windowShape
%                                       <- a HARTLEY GENERATOR SPEC, not a grating
%       1  BG N angle dispprefs dist fps isblank pixSize randState rect values
%                                                                    <- the blank
%
% Ten of the eleven presentations hold exactly ONE stimulus of the middle kind:
% the white-noise generator's parameters (M basis functions, K/L_absmax, sfmax,
% randState), with `presentation_order` the scalar 1. The plan resolves that "a
% Hartley basis function IS a visual_grating" (:135-144) -- and the v1 document
% does not ENUMERATE the basis; it carries the recipe. Expanding it into M
% gratings means running the vhlab generator, which is not a struct
% transformation and is not what this signature authorised.
%
% AND IT IS STILL NOT DONE HERE -- the enumeration is READ, not regenerated.
% The basis those ten presentations played is recorded in the `hartley_calc`
% documents that reference them, so the supplied-sequence branch above
% receives it as data. This guard is what that branch bypasses; on the path
% below, with no enumeration in hand, the refusal stands.
%
% gratingValueFromParameters would happily map such a spec: no angle, no
% sFrequency, no tFrequency means the mapper's getNum default fires three times
% and the emitted document reads "a grating at 0 deg, 0 cyc/deg, 0 Hz". That is
% a hollow document with every field looking measured -- the shape `isFragment`
% and the vacuous-field census exist to catch. So a presentation containing any
% non-grating stimulus is REFUSED here and left as it is.
%
% THE GUARD RECOGNISES THE NEWSTIM CLASS, NOT A WORD (Jess Haley, 2026-10-21).
% It used to pass any stimulus carrying one of angle / sFrequency / tFrequency
% (or a blank flag). `angle` is a parameter of three NewStim classes with three
% meanings, so the key test let through Soph's 57 stochasticgridstim noise
% presentations (`angle` is the grid's rotation) as hollow gratings at 0 cyc/deg,
% Dab's 37 shapemoviestim+angle presentations, and Dab's 171 periodicstim
% imageType 0 presentations (a uniform field in a thin window: flashed bars,
% whose sFrequency has no effect). Each NewStim class is now recognised by the
% required-field set its own verify*.m checks (newStimKind below), and only a
% periodicstim with imageType 1 (square) or 2 (sine), or a blank, is a grating.
% Every other kind is REFUSED with its class named. No new value kind is
% minted here: how noise, bars and shape movies are modelled is still open.
nonGrating = 0;
refusedKinds = {};
for i = 1:numel(stimulusKinds)
    if ~any(strcmp(stimulusKinds{i}, {'grating', 'blank'}))
        nonGrating = nonGrating + 1;
        if ~any(strcmp(stimulusKinds{i}, refusedKinds))
            refusedKinds{end+1} = stimulusKinds{i}; %#ok<AGROW>
        end
    end
end
report.non_grating_stimuli = nonGrating;
if nonGrating > 0
    labels = cellfun(@newStimKindLabel, sort(refusedKinds), 'UniformOutput', false);
    report.reason = ['not a sequence of gratings, refused by class: ' ...
        strjoin(labels, '; ') ...
        ' -- outside the signed sequence-of-gratings case'];
    return;
end

% --- the distinct stimuli ----------------------------------------------------
% Deduped by the VALUE, which is what the emitted document carries. Two v1
% parameter sets differing only in a field the grating value does not model
% (randState, dispprefs, ...) are one document; that is the signed
% "deduped by content". Measured on 20211116: 235 raw stimuli -> 235 distinct,
% so nothing collapses there and the dedup is lossless on that corpus.
values   = cell(1, numel(stimuli));
distinct = {};
mapToDistinct = zeros(1, numel(stimuli));
for i = 1:numel(stimuli)
    values{i} = ndi.migrate.internal.gratingValueFromParameters(stimParameters(stimuli, i));
    hit = 0;
    for d = 1:numel(distinct)
        if isequal(distinct{d}, values{i}); hit = d; break; end
    end
    if hit == 0
        distinct{end+1} = values{i}; %#ok<AGROW>
        hit = numel(distinct);
    end
    mapToDistinct(i) = hit;
end
report.distinct_gratings = numel(distinct);
report.blank_gratings = sum(cellfun(@(v) logical(v.is_blank), distinct));

% --- N standalone visual_grating documents -----------------------------------
gratingIds = cell(1, numel(distinct));
gratingBodies = cell(1, numel(distinct));
for d = 1:numel(distinct)
    gratingIds{d} = did.ido.unique_id();
    g = struct();
    g.document_class = struct('class_name', 'visual_grating', ...
        'class_version', '1.0.0', ...
        'superclasses', struct('class_name', 'data_type', 'class_version', '1.0.0'), ...
        'schema_version', targetVersion);
    g.base = struct('id', gratingIds{d}, 'session_id', sessionId, ...
        'name', sprintf('migrated_visual_grating_%d', d), ...
        'creation_timestamp', datestamp);
    % a field or a `session_id` edge, as the schema in use keeps it
    g = ndi.migrate.internal.withSessionId(g, sessionId);
    % Assigned separately: struct(...) with a struct value distributes.
    g.visual_grating = struct();
    g.visual_grating.value = distinct{d};
    gratingBodies{d} = g;
end

% --- the playlist, REMAPPED onto the distinct set ----------------------------
% v1 indexes `stimuli`; the signed encoding indexes `presented_id`. They differ
% the moment anything dedups, so the remap is the encoding, not a tidy-up.
presentationOrder = mapToDistinct(order);

% --- the timing, if and only if the source really carries it -----------------
times = struct([]);
if isfield(block, 'presentation_time') && isstruct(block.presentation_time)
    times = block.presentation_time;
end
[onsets, durations, timingOk] = trialTiming(times, numel(order));
report.trials_with_timing = sum(timingOk);
if bodyRequired(timingOk)
    report.timing_source = 'inline (deprecated writer form)';
else
    report.timing_source = 'none in the document body (presentation_time.bin not read here)';
end

% --- the manipulation --------------------------------------------------------
manipBody = manipulationBody(presentationId, sessionId, datestamp, ...
    animalId, stimulatorId, gratingIds, presentationOrder, targetVersion);
if bodyRequired(timingOk)
    % storage_mode governs where the SAMPLES live, and the data_body decision
    % puts axes[] on the body exactly when it is `body`. The playlist stays in
    % `timed_sequence.value` either way -- it is the statement's own content,
    % not a sampled payload.
    manipBody.subject_statement.storage_mode = 'body';
    manipBody.subject_statement.datum_type = 'float64';
    manipBody.subject_statement.source_datum_type = 'double';
end

% --- the sampled_body: onsets are an irregular time axis ---------------------
if ~bodyRequired(timingOk)
    return;
end
timeAxis = axisEntry(struct('node', '', 'name', 'time'), numel(order));
timeAxis.regular     = false;   % trial onsets are irregular by construction
timeAxis.source_unit = 's';
timeAxis.values = struct('values', {onsets}, 'source_values', {onsets});

bodyDoc = struct();
bodyDoc.document_class = struct('class_name', 'sampled_body', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_body', 'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
% `statement` is mustBeNonEmpty on data_body; it points at the manipulation,
% which IS a subject_statement descendant. Populated by construction here --
% this branch is unreachable without a manipulation.
bodyDoc.depends_on = struct('name', {'statement'}, 'value', {presentationId});
bodyDoc.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_stimulus_sequence_timing', 'creation_timestamp', datestamp);
% a field or a `session_id` edge, as the schema in use keeps it
bodyDoc = ndi.migrate.internal.withSessionId(bodyDoc, sessionId);
bodyDoc.sampled_body = struct();
% ONE axis, because the payload is 1-D: one duration per trial, indexed by the
% onset. `datum_order` stays empty -- the schema says it is meaningless for a
% 1-D body -- and `byte_order` is left to the caller that serialises the bytes.
bodyDoc.sampled_body.axes = timeAxis;
records = durations(:);
end

% ===================== assembly helpers ====================================

function manipBody = manipulationBody(presentationId, sessionId, datestamp, ...
        animalId, stimulatorId, presentedIds, presentationOrder, targetVersion)
%MANIPULATIONBODY The one `timed_sequence_manipulation`, shared by both paths.
%   Both the enumerated case (the presentation lists its stimuli) and the
%   supplied-enumeration case (the presentation is a generator recipe and the
%   basis comes from the calculators) produce the SAME document; they differ
%   only in where the refs and the playlist come from. Written once so the two
%   cannot drift into emitting differently-shaped documents.
manipBody = struct();
manipBody.document_class = struct('class_name', 'timed_sequence_manipulation', ...
    'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_manipulation', 'class_version', '1.0.0'), ...
        struct('class_name', 'timed_sequence',       'class_version', '1.0.0')], ...
    'schema_version', targetVersion);

% EVERY EDGE BELOW IS EMITTED ONLY WITH A REAL VALUE. An edge present with an
% empty value is skipped by +did2/+validate/references.m:90 and then reads as a
% fact that was recorded -- the invented-empty-edge pattern that put 2,670
% `stimulus_presentation.element_id` rows and 4,563
% `image_observation.subject_id` rows into the census.
deps = struct('name', {}, 'value', {});
deps(end+1) = struct('name', 'subject_id', 'value', animalId);
if ~isempty(stimulatorId)
    % T7: the stimulator is the INSTRUMENT of the interaction. This is the
    % signed replacement for v1 `stimulus_element_id`, and it is optional
    % (subject_interaction declares instrument_id mustBeNonEmpty false), so an
    % absent stimulator is simply not asserted.
    deps(end+1) = struct('name', 'instrument_id', 'value', stimulatorId);
end
% NUMBERED, not repeated. `timed_sequence` declares `presented_id` with
% multiple:true, and the sqlite sidecar is `CREATE TABLE depends_on (... PRIMARY
% KEY (doc_id, name))` -- so a document physically cannot carry two edges of the
% same name, and `<stem>_<k>` is the spelling every other multiple family uses
% (epochMint `sprintf('time_reference_%d', r)`, syncgraph
% `clock_alignment_configuration_%d`, daqsystem `acquisition_metadata_reader_%d`).
% NOTE FOR THE TEAM: 12 of the 13 multiple deps in V_eta declare their name
% WITH the `_#` marker; `presented_id` and `undirected_relation.entities` do
% not. Nothing rejects the numbered spelling (there is no undeclared-dependency
% check), but the family instruments -- silentLoss `countFamily`,
% timeReferenceFamilies -- only recognise a family whose SCHEMA name carries
% `#`, so these edges are invisible to them until the declaration is amended.
% That is a schema question, deliberately not answered here.
for d = 1:numel(presentedIds)
    deps(end+1) = struct('name', sprintf('presented_id_%d', d), ...
        'value', presentedIds{d}); %#ok<AGROW>
end
manipBody.depends_on = deps;

% THE PRESERVED ID. "decomposed around its preserved id, not dissolved."
manipBody.base = struct('id', presentationId, 'session_id', sessionId, ...
    'name', 'migrated_stimulus_sequence', 'creation_timestamp', datestamp);
% a field or a `session_id` edge, as the schema in use keeps it
manipBody = ndi.migrate.internal.withSessionId(manipBody, sessionId);

manipBody.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'visual grating'), ...
    'storage_mode', 'inline');
manipBody.subject_interaction = struct( ...
    'method', struct('node', '', 'name', 'visual stimulus presentation'));
manipBody.subject_manipulation = struct();
manipBody.timed_sequence = struct();
% Separately assigned, and as a ROW: presentation_order is a matrix field and
% struct(...) would distribute a non-scalar into a struct array.
manipBody.timed_sequence.value = struct();
manipBody.timed_sequence.value.presentation_order = presentationOrder;
end

function [n, reason] = severalAnimals(n, route)
%SEVERALANIMALS The pass-through for a presentation that resolves to SEVERAL
%   animals in its session (Jess Haley, 2026-10-21). The decided shape -- one
%   cohort entity per session, each animal member_of it, and one manipulation
%   of the cohort with `distributive` true -- needs
%   subject_statement.distributive, which the did-schema this pass writes
%   (v_eta-pre73, pinned by the NDI e2e workflows) does not declare. So the
%   presentation is left as v1, with this reason, and counted
%   (`several_animals`); no N per-animal copies are written.
reason = sprintf(['several animals: the %s route resolves to %d animals in ' ...
    'this session; the decided cohort + distributive shape is not ' ...
    'expressible on the schema this pass writes (no ' ...
    'subject_statement.distributive) -- left as v1'], route, n);
end

function [presentedIds, order, frameTimes, why] = readSequence(sequence)
%READSEQUENCE Validate a supplied enumeration and return its three parts.
%   Refuses rather than repairs. A playlist index outside the ref list would
%   name no document, and a frame-time vector of a different length than the
%   playlist means the two halves describe different runs -- both would emit a
%   document that validates while saying something untrue.
presentedIds = {};
order        = [];
frameTimes   = [];
why          = '';

if ~isstruct(sequence) || ~isscalar(sequence)
    why = 'supplied sequence is not a scalar struct';
    return;
end
if ~isfield(sequence, 'presented_ids') || ~iscell(sequence.presented_ids) ...
        || isempty(sequence.presented_ids)
    why = 'supplied sequence carries no presented_ids';
    return;
end
presentedIds = sequence.presented_ids(:)';
for k = 1:numel(presentedIds)
    if isempty(presentedIds{k}) || ~(ischar(presentedIds{k}) ...
            || (isstring(presentedIds{k}) && isscalar(presentedIds{k})))
        why = sprintf('supplied presented_ids(%d) is not a non-empty id', k);
        presentedIds = {};
        return;
    end
    presentedIds{k} = char(presentedIds{k});
end
if ~isfield(sequence, 'order') || ~isnumeric(sequence.order) || isempty(sequence.order)
    why = 'supplied sequence carries no order';
    presentedIds = {};
    return;
end
order = double(sequence.order(:)');
bad = sum(order < 1 | order > numel(presentedIds) | order ~= floor(order));
if bad > 0
    why = sprintf(['supplied order has %d entr(ies) outside the ' ...
        'presented_ids list'], bad);
    presentedIds = {}; order = [];
    return;
end
if isfield(sequence, 'frame_times') && isnumeric(sequence.frame_times) ...
        && ~isempty(sequence.frame_times)
    frameTimes = double(sequence.frame_times(:)');
    if numel(frameTimes) ~= numel(order)
        why = sprintf(['supplied frame_times has %d entr(ies) for %d frame(s)'], ...
            numel(frameTimes), numel(order));
        presentedIds = {}; order = []; frameTimes = [];
        return;
    end
end
end

function ax = axisEntry(variable, n)
%AXISENTRY One signed axis entry, every field present, in a FIXED order.
%   The twin of the same helper in stimulusPresentationToManipulation and of
%   DID-matlab's +migrators_j/private/jAxis.m. Every one of the ten declared
%   sub-fields is set, to the schema's own blank where there is nothing to say:
%   MATLAB concatenates struct arrays only when the operands share a field set
%   AND its order, and a present-but-blank field is indistinguishable from an
%   absent one to the validator, so nothing is asserted that was not measured.
ax = struct();
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

function tf = bodyRequired(timingOk)
%BODYREQUIRED True exactly when EVERY trial has a real onset and offset.
%   All-or-nothing on purpose: a partly-populated time axis would have to fill
%   the gaps with something, and every candidate filler (0, NaN, the previous
%   onset) reads as a measurement. Note `all([])` is true, so the emptiness
%   test is load-bearing rather than defensive.
tf = ~isempty(timingOk) && all(timingOk);
end

function kind = newStimKind(params)
%NEWSTIMKIND The NewStim class (and, for periodicstim, the image type) of ONE v1
%   stimulus parameter set. The v1 document does not record the class
%   (NDI's NewStimStims reader keeps only getparameters(...)), so it is
%   RECOGNISED from the required-field set each class's own verify*.m checks
%   (vhlab-NewStim-matlab, Stimuli/@<class>/private/verify*.m). A POSITIVE test:
%   a parameter set no class matches is `unrecognised`, never a grating.
%
%     blank               `isblank` (or is_blank / blank) true -- a NewStim
%                         convention, not a class; every blank in the corpora is
%                         a 1x1-pixel grey stochasticgridstim
%     grating             periodicstim, imageType 1 (square) or 2 (sine)
%     periodicstim_bars   periodicstim, imageType 0 (a uniform field)
%     periodicstim_other  periodicstim, any other imageType
%     stochasticgridstim  noise grid
%     blinkingstim        sparse blinking squares
%     shapemoviestim      shape movie (the shapes are not in getparameters)
%     hartleystim         a Hartley generator recipe (enumerated elsewhere)
%     ambiguous           more than one class's required set is present
%     unrecognised        no class's required set is present
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
        % hartleystim: its verifyhartleystim.m is a verbatim copy of
        % periodicstim's and does not describe what the class writes; the
        % generator recipe on 20211116 (10 of 10) carries these four keys and
        % none of sFrequency / tFrequency / imageType.
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
%NEWSTIMKINDLABEL The reason-string name of a refused kind.
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
%NEWSTIMKINDCOUNTS One counter per kind newStimKind can return, all present
%   and zero, so every report carries the same fields (Rule 5).
k = struct('grating', 0, 'blank', 0, 'periodicstim_bars', 0, ...
    'periodicstim_other', 0, 'stochasticgridstim', 0, 'blinkingstim', 0, ...
    'shapemoviestim', 0, 'hartleystim', 0, 'ambiguous', 0, 'unrecognised', 0);
end

function r = newReport()
r = struct( ...
    'stimuli_read',        0, ...
    'non_grating_stimuli', 0, ...
    'stimulus_kinds',      newStimKindCounts(), ...
    'distinct_gratings',   0, ...
    'blank_gratings',      0, ...
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
    'instrument_resolved', false, ...
    'epoch_id',            '', ...
    'animal_source',       '', ...
    'reason',              '');
end

% ===================== v1 readers ==========================================

function stimuli = stimulusArray(block)
%STIMULUSARRAY The `stimuli` list as a struct ARRAY.
%   jsondecode collapses a one-element JSON array of objects to a scalar
%   struct, and 10 of the 11 20211116 presentations are exactly that shape, so
%   a function that assumed an array would mis-handle the common case.
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
%ORDERVECTOR The playlist as a row of doubles. A single-trial presentation
%   decodes to a scalar, not a vector -- again the 10-of-11 case.
order = [];
if ~isfield(block, 'presentation_order'); return; end
raw = block.presentation_order;
if isnumeric(raw) && ~isempty(raw)
    order = double(raw(:)');
end
end

function [onsets, durations, ok] = trialTiming(times, nTrials)
%TRIALTIMING Per-trial onset + duration from an INLINE presentation_time, and a
%   per-trial flag saying whether both were really there. Never substitutes a
%   default for a missing time.
onsets    = zeros(1, nTrials);
durations = zeros(1, nTrials);
ok        = false(1, nTrials);
if ~isstruct(times) || isempty(times); return; end
for k = 1:nTrials
    if numel(times) < k; return; end
    [onset, haveOnset]   = numericField(times(k), 'onset');
    [offset, haveOffset] = numericField(times(k), 'offset');
    if ~haveOnset || ~haveOffset; continue; end
    onsets(k)    = onset;
    durations(k) = offset - onset;
    ok(k)        = true;
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
%STIMPARAMETERS One stimulus's v1 parameter struct, or an empty struct.
%   SCALAR is required, not just struct: gratingValueFromParameters declares
%   `(1,1) struct`, so a non-scalar would throw out of a batch pass. Returning
%   the empty struct instead routes the oddity into newStimKind (unrecognised), which refuses
%   the document with a stated reason -- a refusal beats an exception, and both
%   beat mapping an unreadable shape onto eight zeros.
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
    if isstruct(d) && isfield(d, 'name') && strcmp(char(d.name), name) ...
            && isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
        return;
    end
end
end
