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
%     extraBodies    {} on the single-subject path. On the MULTI-SUBJECT path
%                    (the presentation resolves to N>1 responding animals) it
%                    carries the ONE standalone `timed_sequence` body-of-record
%                    plus the N-1 further per-subject
%                    `timed_sequence_manipulation` leaves -- the caller mints
%                    all of them alongside `manipBody` (the primary, first
%                    subject's manip) and the shared gratings.
%
%   MULTI-SUBJECT (storage_mode: reference)
%   ------------------------------------------------------------------------
%   The signed model (V_eta_stimulus_model_plan.md, worked example :73-88)
%   makes multi-subject fall out of `storage_mode`, not a structural fork: a
%   presentation shown to N animals becomes ONE shared standalone
%   `timed_sequence` (the body-of-record: the deduped `presented_id_#` edges +
%   the `value.presentation_order` playlist) and N `timed_sequence_manipulation`
%   leaves, one per subject, each referencing that body-of-record through a
%   `timed_sequence_id` edge (storage_mode = 'reference') INSTEAD of carrying
%   inline `presented_id_#` edges. The heavy `visual_grating` config docs are
%   minted ONCE and shared by reference; nothing about the stimuli is
%   duplicated across subjects.
%
%   base.id / THE FAN-IN. The preserved v1 presentation id sits on the
%   BODY-OF-RECORD (the standalone `timed_sequence`), per the plan's "the v1
%   stimulus_presentation id is preserved on the body-of-record it becomes (the
%   `timed_sequence`)" (:102-104). So `stimulus_response_scalar.
%   stimulus_presentation_id`, `hartley_calc.stimulus_presentation_id` and
%   `control_designation.timed_sequence_id` all keep resolving to it. The N
%   manipulations each take a FRESH `did.ido.unique_id()` -- two documents
%   cannot share the sqlite PRIMARY KEY `documents(id TEXT PRIMARY KEY)`, and
%   nothing in v1 references a per-subject manipulation. (On the single-subject
%   path the ONE manip is itself the body-of-record and keeps the id, inline
%   storage_mode, unchanged.)
%
%   Each manip STILL carries `timed_sequence.value.presentation_order`:
%   `timed_sequence_manipulation` is-a `timed_sequence`, `value` is
%   mustBeNonEmpty, and v1_to_v2 ensureClassBlocks materialises the
%   `timed_sequence` block on every such document, so an empty one would
%   quarantine (missingField / vacuousField). The playlist is a small index
%   array; the no-duplication rule is about the config docs, which are shared.
%
%   TIMING in reference mode is DEFERRED: no v1 multi-subject presentation
%   exists (on 20211116 all 11 presentations resolve to exactly one subject),
%   and the signed reference shape gives the sampled_body/axis tier no home on a
%   data_type body-of-record. Recorded in `report.timing_source` rather than
%   forced into an invented slot; if a multi-subject presentation carrying real
%   timing ever appears, that tier is the follow-up.
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
% extraBodies: the additional documents the MULTI-SUBJECT storage_mode:reference
% decomposition mints beyond the primary manipulation and the shared gratings --
% the ONE standalone `timed_sequence` body-of-record plus the N-1 further
% per-subject `timed_sequence_manipulation` leaves. Stays {} on the
% single-subject path, whose execution below is byte-for-byte unchanged.
extraBodies = {};

% Rule 5: the report's denominators exist before any early return, so a
% refusal prints the same SHAPE as a success and "fell through" is never
% inferable only by subtracting two other counters.
report = newReport();

presentationId = baseField(v1Body, 'id', '');
sessionId      = baseField(v1Body, 'session_id', '');
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

% subject_id is mustBeNonEmpty on subject_statement and RequiredDependencies is
% armed by default (+did2/+schema/cache.m), so no animal means no manipulation.
animals = resolver.subjectsForPresentation(presentationId);
report.subjects_resolved = numel(animals);
report.animal_source = 'response';
if isempty(animals)
    % FORK 1 (team call 2026-08-22): a presentation with NO stimulus_response
    % linking it to a responding element -- the non-tuning case, e.g. an
    % opto/bath ephys experiment that computes no per-stimulus response -- is
    % still attributed to the animal RECORDED IN ITS OWN EPOCH. Session-scoped,
    % because a v1 epoch id is a NAME that repeats across sessions and the bare
    % map pools them. Measured on Dab (run #4, 1242 refused): 1174 resolve to
    % exactly one subject, 0 to several, 68 to none. The 68 (all session-id
    % gaps -- measured 68/0, none a genuinely stimulus-only epoch) are the input
    % to FORK 2 in the scoped==0 branch below.
    scoped = resolver.subjectsViaEpochScoped(presentationId);
    if numel(scoped) == 1
        animals = scoped;
        report.animal_source = 'epoch';
    elseif numel(scoped) > 1
        report.animal_source = 'none';
        report.reason = sprintf(['no responding animal; the epoch names %d ' ...
            'subjects -- ambiguous'], numel(scoped));
        return;
    else
        report.animal_source = 'none';
        nEl = resolver.epochElementCountScoped(presentationId);
        if nEl == 0
            % (b) 2026-08-25: split the no-element case so "genuinely records
            % nothing" and "a session-id gap" are distinguishable. If the bare
            % epoch NAME carries recording elements in ANOTHER session, the
            % recording exists but is keyed to a different session_id (a
            % linkage gap, potentially recoverable); if it carries none
            % anywhere, the epoch is genuinely stimulus-only.
            nAny = resolver.epochElementCountUnscoped(presentationId);
            if nAny > 0
                % SESSION-ID GAP. FORK 2 (built 2026-08-25 at the user's
                % direction; PROPOSED, not team-signed like fork 1, because it
                % crosses a session boundary). The epoch name carries a
                % recording element only in a sibling session. Widen there and
                % attribute IFF exactly one subject is reachable; refuse if
                % several (ambiguous across sessions) or none resolves. It fires
                % only here -- scoped == 0 AND nEl == 0 -- so it can never touch
                % a presentation fork 1 already attributed and cannot regress
                % the in-session count. See
                % bodyResolver.subjectsViaEpochSibling for why the exactly-one
                % guard is what makes the cross-session hypothesis testable
                % rather than assumed.
                sibling = resolver.subjectsViaEpochSibling(presentationId);
                report.sibling_subjects = numel(sibling);
                if numel(sibling) == 1
                    animals = sibling;
                    report.animal_source = 'epoch_sibling';
                elseif numel(sibling) > 1
                    report.reason = sprintf(['no responding animal; the epoch ' ...
                        'name records only in sibling session(s), resolving to ' ...
                        '%d subjects -- ambiguous across sessions'], ...
                        numel(sibling));
                    return;
                else
                    report.reason = ['no responding animal; the epoch name ' ...
                        'records in a sibling session, but no element there ' ...
                        'resolves to a subject'];
                    return;
                end
            else
                report.reason = ['no responding animal; the epoch has no ' ...
                    'recorded element in any session (a stimulus-only epoch)'];
                return;
            end
        else
            report.reason = sprintf(['no responding animal; the epoch''s %d ' ...
                'recorded element(s) resolve to no subject'], nEl);
            return;
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
    % MULTI-SUBJECT: one shared timed_sequence body-of-record (over the SUPPLIED
    % basis refs) + N reference manipulations. The frameTimes axis tier is
    % deferred in reference mode (see the header) -- recorded, not invented.
    if numel(animals) > 1
        [manipBody, extraBodies] = referenceManipulations(presentationId, ...
            sessionId, datestamp, animals, stimulatorId, presentedIds, ...
            presentationOrder, targetVersion);
        report.timing_source = ['multi-subject reference mode -- frameTimes ' ...
            'axis tier deferred (no v1 multi-subject presentation exists)'];
        if ~isempty(frameTimes)
            report.trials_with_timing = numel(frameTimes);
        end
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
nonGrating = 0;
for i = 1:numel(stimuli)
    if ~isGratingParameters(stimParameters(stimuli, i))
        nonGrating = nonGrating + 1;
    end
end
report.non_grating_stimuli = nonGrating;
if nonGrating > 0
    report.reason = sprintf(['%d of %d stimuli carry no grating parameter ' ...
        '(angle / spatial frequency / temporal frequency) and are not marked ' ...
        'blank -- outside the signed sequence-of-gratings case'], ...
        nonGrating, numel(stimuli));
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
    % Assigned separately: struct(...) with a struct value distributes.
    g.visual_grating = struct();
    g.visual_grating.value = distinct{d};
    gratingBodies{d} = g;
end

% --- the playlist, REMAPPED onto the distinct set ----------------------------
% v1 indexes `stimuli`; the signed encoding indexes `presented_id`. They differ
% the moment anything dedups, so the remap is the encoding, not a tidy-up.
presentationOrder = mapToDistinct(order);

% --- MULTI-SUBJECT: one shared body-of-record + N reference manipulations -----
% The dedup + N standalone visual_grating mint above is SHARED with the
% single-subject path -- the gratings are minted once (gratingIds/gratingBodies)
% and referenced by the ONE standalone timed_sequence, not per subject. Only the
% manipulation shape forks on numel(animals). The per-trial timing tier (the
% sampled_body below) is deferred in reference mode; recorded, not invented.
if numel(animals) > 1
    [manipBody, extraBodies] = referenceManipulations(presentationId, ...
        sessionId, datestamp, animals, stimulatorId, gratingIds, ...
        presentationOrder, targetVersion);
    report.timing_source = ['multi-subject reference mode -- per-trial timing ' ...
        'tier deferred (no v1 multi-subject presentation exists)'];
    return;
end

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

function [primaryManip, extraBodies] = referenceManipulations(presentationId, ...
        sessionId, datestamp, animals, stimulatorId, presentedIds, ...
        presentationOrder, targetVersion)
%REFERENCEMANIPULATIONS The multi-subject storage_mode:reference shape.
%   ONE standalone `timed_sequence` body-of-record + N
%   `timed_sequence_manipulation` leaves (one per subject). The body-of-record
%   carries the PRESERVED presentation id, the `presented_id_#` edges (so the
%   config docs are shared, not duplicated) and the `value.presentation_order`
%   playlist; each manipulation carries a FRESH id, its own `subject_id`, the
%   stimulator's `instrument_id`, storage_mode='reference', a `timed_sequence_id`
%   edge to the body-of-record INSTEAD of inline `presented_id_#` edges, and its
%   own copy of the (required, non-empty) playlist.
%
%   base.id: the body-of-record keeps the presentation id -- signed plan "the v1
%   stimulus_presentation id is preserved on the body-of-record it becomes (the
%   `timed_sequence`)" -- so the fan-in edges
%   (`stimulus_response_scalar.stimulus_presentation_id`,
%   `hartley_calc.stimulus_presentation_id`,
%   `control_designation.timed_sequence_id`) all resolve to it. Each manip takes
%   a fresh `did.ido.unique_id()`: two documents cannot share the sqlite PRIMARY
%   KEY, and nothing in v1 references a per-subject manipulation.
%
%   `primaryManip` is the first subject's manipulation, returned as the
%   function's `manipBody`; `extraBodies` is {the body-of-record, then
%   manip_2..manip_N}. The caller mints all of them.

% --- the body-of-record: a standalone timed_sequence -------------------------
seq = struct();
seq.document_class = struct('class_name', 'timed_sequence', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_type', 'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
% presented_id_1..N onto the body-of-record. Same numbered-family spelling and
% same empty-edge discipline as manipulationBody: an edge is emitted only with a
% real value, never a blank one references.m:90 would skip.
deps = struct('name', {}, 'value', {});
for d = 1:numel(presentedIds)
    deps(end+1) = struct('name', sprintf('presented_id_%d', d), ...
        'value', presentedIds{d}); %#ok<AGROW>
end
seq.depends_on = deps;
% THE PRESERVED ID sits on the body-of-record in reference mode.
seq.base = struct('id', presentationId, 'session_id', sessionId, ...
    'name', 'migrated_stimulus_sequence', 'creation_timestamp', datestamp);
seq.timed_sequence = struct();
seq.timed_sequence.value = struct();
seq.timed_sequence.value.presentation_order = presentationOrder;

extraBodies = {seq};
primaryManip = [];
for k = 1:numel(animals)
    m = referenceManipulation(sessionId, datestamp, animals{k}, stimulatorId, ...
        presentationId, presentationOrder, targetVersion);
    if k == 1
        primaryManip = m;
    else
        extraBodies{end+1} = m; %#ok<AGROW>
    end
end
end

function m = referenceManipulation(sessionId, datestamp, animalId, stimulatorId, ...
        sequenceId, presentationOrder, targetVersion)
%REFERENCEMANIPULATION One per-subject `timed_sequence_manipulation` in
%   storage_mode:reference. Identical to manipulationBody in everything the two
%   share (variable / method / subject_manipulation / the required, non-empty
%   `timed_sequence.value` playlist) so the two shapes cannot drift; it differs
%   ONLY in the three things reference mode changes -- a fresh id, a
%   `timed_sequence_id` edge in place of inline `presented_id_#` edges, and
%   storage_mode='reference'.
m = struct();
m.document_class = struct('class_name', 'timed_sequence_manipulation', ...
    'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_manipulation', 'class_version', '1.0.0'), ...
        struct('class_name', 'timed_sequence',       'class_version', '1.0.0')], ...
    'schema_version', targetVersion);

% EVERY EDGE EMITTED ONLY WITH A REAL VALUE (the invented-empty-edge discipline,
% as in manipulationBody). subject_id is REQUIRED and mustBeNonEmpty; the caller
% only ever hands non-empty, resolver-de-duplicated animal ids.
deps = struct('name', {}, 'value', {});
deps(end+1) = struct('name', 'subject_id', 'value', animalId);
if ~isempty(stimulatorId)
    deps(end+1) = struct('name', 'instrument_id', 'value', stimulatorId);
end
% The shared body-of-record, INSTEAD of inline presented_id_# edges. Optional
% (mustBeNonEmpty false) but always populated here -- reference mode is
% meaningless without it.
deps(end+1) = struct('name', 'timed_sequence_id', 'value', sequenceId);
m.depends_on = deps;

% FRESH id: the presentation id lives on the body-of-record, not here.
m.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_stimulus_sequence', 'creation_timestamp', datestamp);

m.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'visual grating'), ...
    'storage_mode', 'reference');
m.subject_interaction = struct( ...
    'method', struct('node', '', 'name', 'visual stimulus presentation'));
m.subject_manipulation = struct();
% `timed_sequence.value` is mustBeNonEmpty and ensureClassBlocks materialises
% the block on this leaf, so it is populated even in reference mode -- an empty
% one quarantines. The playlist is a small index array; the config docs are the
% thing shared by reference, not this.
m.timed_sequence = struct();
m.timed_sequence.value = struct();
m.timed_sequence.value.presentation_order = presentationOrder;
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

function tf = isGratingParameters(params)
%ISGRATINGPARAMETERS True when this v1 parameter set describes a grating this
%   function can type WITHOUT inventing anything: it carries at least one of
%   the three defining quantities gratingValueFromParameters reads, or it says
%   outright that it is a blank. Deliberately a POSITIVE test -- listing the
%   generator keys to exclude would pass every stimulus shape nobody has met
%   yet, which is the wrong default for a mapper whose misses are silent zeros.
%   The names are exactly the ones gratingValueFromParameters looks for, so the
%   two cannot drift into disagreeing about what is readable.
tf = false;
defining = {'angle', 'orientation', ...
            'sFrequency', 'spatial_frequency', 'sf', ...
            'tFrequency', 'temporal_frequency', 'tf'};
for k = 1:numel(defining)
    if isfield(params, defining{k}) && ~isempty(params.(defining{k}))
        tf = true;
        return;
    end
end
blankNames = {'isblank', 'is_blank', 'blank'};
for k = 1:numel(blankNames)
    if isfield(params, blankNames{k}) && ~isempty(params.(blankNames{k}))
        tf = true;
        return;
    end
end
end

function r = newReport()
r = struct( ...
    'stimuli_read',        0, ...
    'non_grating_stimuli', 0, ...
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
%   the blank instead routes the oddity into isGratingParameters, which refuses
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
