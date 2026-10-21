classdef TestMigrateLocalEtaDab < matlab.unittest.TestCase
%TESTMIGRATELOCALETADAB The Dab corpus through the WHOLE V_eta pipeline.
%
%   The FOURTH corpus to get the PRED / 20211116 / Soph treatment, and the
%   one that exercises a path none of the others do: ~27,561 v1 documents
%   (~35 MB compressed), migrated in full through ndi.migrate.local, opened
%   through ndi.session.dir, and read back through the object API.
%
%   WHY DAB IS WORTH ITS OWN e2e. Dab is the WIDEST corpus (26 v1 classes)
%   and the only one that holds `ontologyTableRow` at scale (~6,205 docs).
%   That class's decomposition -- ndi.migrate.internal.ontologyRowSubjects,
%   the D10/D11 two-tier subject fan-out (#53) -- is proven only by a unit
%   test (TestOntologyRowSubjects) and has NEVER run over a real corpus. Dab
%   also carries the widest read-back surface: ingestion (~9,419 docs),
%   openMINDS (~2,344), and syncrule_mapping (~2,484, the class with the live
%   NDI query). Its Bar-1 (0 quarantine / 0 orphans) is gated independently on
%   the DID-matlab side (test-corpus.yml); what THIS workflow uniquely adds is
%   the NDI second passes + object-layer read-back on Dab's real documents.
%
%   HARD ASSERTS, because Dab's DID side already proves them clean: the corpus
%   size, 0 quarantine, 0 orphans, 0 fragments. If the ontologyRowSubjects
%   fan-out breaks at scale, THIS is where it turns red -- that is the point of
%   running it over the whole corpus rather than a fixture.
%
%   REPORT-ONLY ON THIS FIRST LANDING for the census + navigation + fan-out
%   count methods, DELIBERATELY (same discipline as the Soph landing). Dab's
%   exact pass-1 unconverted set, final survivor set, per-session read-back
%   counts, and the ontologyRowSubjects output volume are MEASURED here before
%   they are pinned -- arming a gate against a guessed 27k-document set would
%   either pass vacuously or fail on a persist-legitimate survivor.
%
%   SKIPS, NEVER FAILS, when the environment cannot support it: no mksqlite,
%   NDI_TEST_ETA unset, DID_SCHEMA_PATH unset, or the corpus will not download.
%   "Could not run" and "ran and found a defect" are different results and
%   must stay distinguishable.
%
%   NOT VERIFIED BY EXECUTION: there is no MATLAB in the authoring container;
%   validation runs via CI.

    properties
        SessionRoot
        CorpusDir
        Result
        Bodies
    end

    methods (TestClassSetup)

        function gateAndMigrate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~etaEnabled()
                assumeFail(testCase, 'NDI_TEST_ETA not truthy; skipping V_eta e2e.');
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; skipping.');
            end
            try
                testCase.CorpusDir = ensureDabCorpus();
            catch ME
                assumeFail(testCase, sprintf( ...
                    'could not fetch the Dab corpus (%s); skipping.', ...
                    ME.message));
            end

            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));

            % PHASE TIMING, kept from the Soph landing so a future timeout is
            % localised from the log rather than guessed.
            t = tic;
            testCase.Bodies = readCorpusBodies(testCase.CorpusDir);
            fprintf('  [Dab timing] readCorpusBodies: %d docs in %.1f s\n', ...
                numel(testCase.Bodies), toc(t));
            t = tic;
            buildV1Sqlite(fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite'), ...
                testCase.Bodies);
            fprintf('  [Dab timing] buildV1Sqlite: %.1f s\n', toc(t));

            t = tic;
            testCase.Result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', true, 'TargetVersion', 'V_eta', 'Backup', false);
            fprintf('  [Dab timing] ndi.migrate.local: %.1f s\n', toc(t));
        end

    end

    methods (TestClassTeardown)
        function cleanup(testCase)
            try
                if ~isempty(testCase.SessionRoot) && isfolder(testCase.SessionRoot)
                    rmdir(testCase.SessionRoot, 's');
                end
            catch
            end
        end
    end

    methods (Test)

        function testTheWholeCorpusMigratesWithNothingQuarantinedOrDangling(testCase)
            % DENOMINATOR FIRST. A pass over zero documents quarantines zero
            % documents, and that reading prints the same digit as a clean
            % migration -- so the corpus size is asserted before anything else.
            verifyEqual(testCase, numel(testCase.Bodies), 27561, sprintf( ...
                ['the Dab corpus did not read as 27561 documents (got %d); ' ...
                 'every assertion here would be about a different corpus'], ...
                numel(testCase.Bodies)));
            verifyGreaterThan(testCase, testCase.Result.summary.total, 0, ...
                'the migration saw no documents at all');

            % HARD, and this is the arm the whole workflow exists for: the
            % ontologyRowSubjects fan-out (#53) runs here at scale for the first
            % time. If it quarantines a row, this turns red.
            verifyEmpty(testCase, testCase.Result.quarantine, ...
                quarantineDiag(testCase.Result));

            % THE GRAPH CLOSES. The fan-out mints subjects + typed statements
            % that reference each other and the row's ontology terms; a dangling
            % edge among ~6,205 fanned-out rows would show here.
            verifyEqual(testCase, testCase.Result.references.orphan_count, 0, ...
                sprintf('the migrated graph does not close: %d orphan(s). %s', ...
                    testCase.Result.references.orphan_count, ...
                    resultDiag(testCase.Result)));
            verifyGreaterThan(testCase, testCase.Result.references.edges_examined, 0, ...
                ['the reference sweep examined 0 edges, so its 0 orphans is a ' ...
                 'statement about the sweep and not about the corpus']);
        end

        function testEveryDocumentThatDidNotConvertDidSoDeliberately(testCase)
            % REPORT-ONLY ON THIS FIRST LANDING (see the class header). The
            % pass-1 conversion census names every class a single-document
            % migrator handed straight back; the deliberate-vs-accidental split
            % is read from THIS run's output before it is pinned. The
            % denominator IS asserted -- a census that read nothing is the
            % silentLoss failure and must not masquerade as "all converted".
            s = testCase.Result.summary;

            fprintf(['\n  PASS-1 CONVERSION CENSUS (Dab)\n' ...
                     '    DENOMINATOR: %d document(s) read, %d migrated, ' ...
                     '%d quarantined\n' ...
                     '    unconverted (migrator returned its input): %d\n' ...
                     '    fragments (emitted, but hollow):           %d\n'], ...
                s.total, s.migrated_count, s.quarantine_count, ...
                s.unconverted_count, s.fragment_count);
            ndi.unittest.migrate.printClassTable(s.unconverted_by_class, '    unconverted');
            ndi.unittest.migrate.printClassTable(s.fragment_by_class,    '    fragment');

            verifyEqual(testCase, s.total, 27561, ...
                'the pass did not see 27561 documents; this figure is about a different corpus');

            % A FRAGMENT IS NEVER DELIBERATE -- a document the migrator DID emit
            % that carries nothing (the isFragment failure). 0 on Dab's DID side.
            verifyEqual(testCase, s.fragment_count, 0, sprintf( ...
                ['%d document(s) migrated to a FRAGMENT. A passthrough is a ' ...
                 'deferral; a fragment is silent loss.'], s.fragment_count));
        end

        function testNoV1DocumentSurvivesUnfoldedInTheFinalOutput(testCase)
            % THE BAR-2 INSTRUMENT, report-only on this first landing. The
            % census above counts pass 1; it cannot see the SECOND PASSES that
            % run afterward (ontologyRowSubjects, stimulusPresentationToTimed-
            % Sequence, resolveDeferredBaths, resolveResponseParameters), so a
            % class that reads "unconverted" there can still reach decided shape.
            % The only sound test of "is this corpus fully at decided shape" is
            % the FINAL output: a v1 SOURCE class name still labelling a
            % destination document did not fold. Measured before it is asserted.
            src = testCase.Bodies;
            dst = destinationBodies(testCase.Result.destination);
            survivors = ndi.unittest.migrate.finalV1SurvivorCensus( ...
                reshape(src, 1, []), reshape(dst, 1, []));

            fprintf(['\n  BAR-2 FINAL-OUTPUT V1 SURVIVOR CENSUS (Dab)\n' ...
                     '    DENOMINATOR: %d source document(s), %d destination ' ...
                     'document(s)\n' ...
                     '    v1 source class names still labelling a destination ' ...
                     'document: %d\n'], ...
                numel(src), numel(dst), numel(survivors));
            if isempty(survivors)
                fprintf('      (none -- every v1 class folded)\n');
            else
                for k = 1:numel(survivors)
                    note = 'UNFOLDED -- a Bar-2 gap unless persist or a declared deferral';
                    if any(strcmp(survivors(k).class_name, {'subject', 'session'}))
                        note = 'persist (v1 class IS the V_eta class)';
                    elseif strcmp(survivors(k).class_name, 'stimulus_response_scalar_parameters_basic')
                        note = 'SIGNED verify-before-delete deferral (#61)';
                    end
                    fprintf('      %6d  %-40s %s\n', survivors(k).count, ...
                        survivors(k).class_name, note);
                end
            end
            % A denominator that read nothing is the silentLoss failure; assert
            % it even while the survivor set itself is report-only.
            verifyEqual(testCase, numel(src), 27561, ...
                'the source census did not read 27561 documents');
            verifyGreaterThan(testCase, numel(dst), 0, ...
                'the destination census read zero documents');
        end

        function testTheMigratedSessionOpensAndReadsBackThroughNDI(testCase)
            % THE HEADLINE. If this errors, nothing below it is meaningful. Dab
            % holds several sessions in ONE migrated database, so this opens ONE
            % of them (the first `session` document) and confirms NDI can reach
            % it on the did2sqlite backend. Per-session object COUNTS are
            % printed, not pinned, on this first landing. What IS asserted: the
            % session opens, the backend chosen is the did2 one, and anything the
            % object API returns is the right TYPE -- zero-with-no-error is the
            % pre-vintage symptom, and a wrong type is a missed rename.
            assertTrue(testCase, isfile(testCase.Result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                testCase.Result.destination));

            migrated = destinationBodies(testCase.Result.destination);
            sessionDoc = findByClass(migrated, 'session');
            assertNotEmpty(testCase, sessionDoc, ...
                'no `session` document in the migrated database');
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), ...
                sessionDoc.base.session_id);

            s = ndi.session.dir(testCase.SessionRoot);
            assertTrue(testCase, isa(s, 'ndi.session.dir'), ...
                'ndi.session.dir did not return a session object');

            selected = ndi.database.fun.opendatabase( ...
                fullfile(testCase.SessionRoot, '.ndi'), s.id());
            assertTrue(testCase, isa(selected, ...
                'ndi.database.implementations.database.did2sqlite'), sprintf( ...
                'opendatabase chose a "%s", not a did2sqlite', class(selected)));

            devs = s.daqsystem_load();
            if isempty(devs); devs = {}; elseif ~iscell(devs); devs = {devs}; end
            for k = 1:numel(devs)
                verifyTrue(testCase, isa(devs{k}, 'ndi.daq.system'), sprintf( ...
                    'daqsystem_load returned a "%s"', class(devs{k})));
            end

            els = s.getelements();
            if isempty(els); els = {}; elseif ~iscell(els); els = {els}; end
            for k = 1:numel(els)
                verifyTrue(testCase, isa(els{k}, 'ndi.element'), sprintf( ...
                    'getelements returned a "%s"', class(els{k})));
            end

            fprintf(['\n  READ-BACK (one of Dab''s session(s))\n' ...
                     '    daqsystem_load: %d object(s)\n' ...
                     '    getelements:    %d object(s)\n'], ...
                numel(devs), numel(els));
        end

        function testSlicesAndTetanusRunsRebuildEveryApproachLabel(testCase)
            % DECIDED BY JESS HALEY 2026-10-21 (dabrowska/V2_decisions.md):
            % each brain slice is an entity `part_of` its animal; one
            % optogenetic-tetanus manipulation per recording run, on the
            % slice, timed by a RELATIVE reference on exp_global_time
            % (relative_to the last "before" epoch; start = that recording's
            % length, duration = the gap to the first "after" recording);
            % the 635 before/after approach documents are dropped because the
            % window rebuilds them (T6). The Nov 28 run filed under the Dec 02
            % animal is its own animal, slice and run.
            %
            % THE LOSSLESS CHECK IS DONE HERE FROM THE DATABASE, not from the
            % pass's report: every v1 label is rebuilt from the windows the
            % database holds and the v1 epoch times.
            r = testCase.Result.secondPass.sliceTetanus;
            assertNotEmpty(testCase, r, 'the slice / tetanus pass did not run');
            fprintf(['\n  SLICE / TETANUS REPORT\n    tetanus %d, slices %d, new animals %d, ' ...
                'labels rebuilt %d/%d, approach docs removed %d, minted quarantined %d\n'], ...
                r.tetanus_manipulations, r.slices, r.new_animals, r.labels_rebuilt, ...
                r.approach_labels, r.approach_labels_removed, r.minted_quarantined);
            verifyEqual(testCase, r.minted_quarantined, 0, 'a minted slice/tetanus document quarantined');
            verifyEqual(testCase, r.approach_labels, 635, 'the pass did not read 635 approach labels');
            verifyEqual(testCase, r.tetanus_manipulations, 56, 'expected 56 tetanus runs (55 stimulators + the Nov 28 run)');
            verifyEqual(testCase, r.slices, 203, 'expected 203 slices (202 bath stimulators + the Nov 28 slice)');
            verifyEqual(testCase, r.new_animals, 1, 'expected one new animal (the Nov 28 run)');
            verifyEqual(testCase, [r.tetanus_with_parameters r.tetanus_without_parameters], [9 47], ...
                'expected 9 runs whose TLS folder states 10 Hz / 20 s and 47 plain TLS');
            verifyEqual(testCase, [r.tetanus_with_target_region r.tetanus_without_target_region], [55 1], ...
                'expected a target region on every run but the Nov 28 one (no treatment record)');
            verifyEqual(testCase, r.labels_not_rebuilt, 0, 'the pass itself could not rebuild a label');

            migrated = destinationBodies(testCase.Result.destination);
            byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for k = 1:numel(migrated)
                byId(migrated{k}.base.id) = migrated{k};
            end
            tet = {}; slices = 0; sliceParts = 0; animals = 0; survivors = 0;
            for k = 1:numel(migrated)
                b = migrated{k};
                switch b.base.name
                    case 'migrated_tetanus_manipulation'; tet{end+1} = b; %#ok<AGROW>
                    case 'migrated_slice'; slices = slices + 1;
                    case 'migrated_slice_part_of'; sliceParts = sliceParts + 1;
                    case 'migrated_nested_date_animal'; animals = animals + 1;
                end
                if strcmp(b.document_class.class_name, 'openminds_stimulus')
                    survivors = survivors + 1;
                end
            end
            fprintf(['  IN THE DATABASE: tetanus manipulations %d, slices %d (part_of %d), ' ...
                'new animals %d, openminds_stimulus left %d\n'], numel(tet), slices, ...
                sliceParts, animals, survivors);
            verifyEqual(testCase, [numel(tet) slices sliceParts animals survivors], [56 203 203 1 0]);

            % ---- the windows, as stored ---------------------------------
            win = struct('stim', {}, 'session', {}, 'epoch', {}, 'start', {}, 'duration', {});
            for k = 1:numel(tet)
                m = tet{k};
                ref = byId(edgeOf(m, 'time_reference_1'));
                ep = byId(edgeOf(ref, 'relative_to'));
                v = ref.relative_reference.value;
                verifyEqual(testCase, v.clock.name, 'exp_global_time');
                win(end+1) = struct('stim', edgeOf(m, 'instrument_id'), ...
                    'session', ep.base.session_id, 'epoch', ep.epoch.local_identifier, ...
                    'start', v.start.seconds, 'duration', v.duration.seconds); %#ok<AGROW>
            end

            % ---- the v1 epoch times and labels ---------------------------
            t0t1 = containers.Map(); labels = {};
            for k = 1:numel(testCase.Bodies)
                txt = testCase.Bodies{k};
                if contains(txt, '"daqreader_mfdaq_epochdata_ingested"') && contains(txt, 'exp_global_time')
                    b = jsondecode(txt);
                    et = b.daqreader_epochdata_ingested.epochtable;
                    i = find(strcmp(cellstr(et.epochclock), 'exp_global_time'), 1);
                    t0t1([b.base.session_id '|' b.epochid.epochid]) = [et.t0_t1(1, i) et.t0_t1(2, i)];
                elseif contains(txt, '"openminds_stimulus"') && contains(txt, 'optogenetic tetanus')
                    b = jsondecode(txt);
                    labels{end+1} = b; %#ok<AGROW>
                end
            end
            rebuilt = 0; wrong = 0;
            for k = 1:numel(labels)
                b = labels{k};
                d = b.depends_on; if iscell(d); d = [d{:}]; end
                stim = d(strcmp({d.name}, 'stimulus_element_id')).value;
                t = t0t1([b.base.session_id '|' b.epochid.epochid]);
                truth = 'before';
                if endsWith(b.openminds.fields.name, 'after optogenetic tetanus'); truth = 'after'; end
                best = Inf; pred = '';
                for w = 1:numel(win)
                    if ~strcmp(win(w).stim, stim) || ~strcmp(win(w).session, b.base.session_id); continue; end
                    ref = t0t1([win(w).session '|' win(w).epoch]);
                    ws = ref(1) + win(w).start / 86400;
                    we = ws + win(w).duration / 86400;
                    dist = abs(t(1) - ws);
                    if dist < best
                        best = dist;
                        if t(2) <= ws + 1e-3/86400; pred = 'before';
                        elseif t(1) >= we - 1e-3/86400; pred = 'after';
                        else; pred = ''; end
                    end
                end
                if strcmp(pred, truth); rebuilt = rebuilt + 1; else; wrong = wrong + 1; end
            end
            fprintf('  LABELS REBUILT FROM THE DATABASE WINDOWS: %d/%d (wrong %d)\n', ...
                rebuilt, numel(labels), wrong);
            verifyEqual(testCase, [numel(labels) rebuilt], [635 635], ...
                'not every before/after label rebuilds from the stored tetanus windows');
        end

        function testTheOntologyRowFanOutRunsAtScale(testCase)
            % DAB'S HEADLINE, and the reason it earns its own e2e. The
            % ontologyRowSubjects second pass (#53, local.m ~706) fans each
            % `ontologyTableRow` it can RESOLVE A SUBJECT FOR out into typed
            % subject statements; a row it cannot resolve, or a fan-out that
            % throws (the try/catch falls back to passthrough), leaves the row
            % as `ontology_table_row`. It is proven by a fixture
            % (TestOntologyRowSubjects); Dab is the first real corpus to run it,
            % at ~6,205 rows. REPORT-ONLY on this landing -- the resolved vs
            % surviving split is exactly what this run MEASURES before it is
            % pinned, so nothing about that split is asserted here. The
            % DENOMINATOR is asserted: a fan-out test that read zero source rows
            % would be vacuous, and Dab is the corpus that is supposed to hold
            % them.
            nSrc = 0;
            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                if isfield(j,'document_class') && isfield(j.document_class,'class_name') ...
                        && strcmp(j.document_class.class_name, 'ontologyTableRow')
                    nSrc = nSrc + 1;
                end
            end

            dst = destinationBodies(testCase.Result.destination);
            nSurvive = numel(findAllByClass(dst, 'ontologyTableRow'));
            nSubjects = numel(findAllByClass(dst, 'subject'));

            fprintf(['\n  ONTOLOGY-ROW FAN-OUT (Dab, #53) -- report-only\n' ...
                     '    DENOMINATOR: %d source `ontologyTableRow` document(s)\n' ...
                     '    resolved + fanned out (source - survivors):    %d\n' ...
                     '    surviving as `ontology_table_row` (unresolved): %d\n' ...
                     '    `subject` documents in the output (all sources): %d\n'], ...
                nSrc, nSrc - nSurvive, nSurvive, nSubjects);

            verifyGreaterThan(testCase, nSrc, 0, ...
                ['no `ontologyTableRow` documents in the Dab corpus -- the ' ...
                 'fan-out test would be vacuous, and Dab is the corpus that ' ...
                 'is supposed to hold them']);
            % NOT asserted here: how many rows fan out vs survive. That split is
            % what this landing measures; pinning it against a guessed count
            % would fail on a legitimately-unresolvable row. The clean-migration
            % guarantee (0 quarantine / 0 orphans) is the hard gate above.
        end

        function testStimulusPresentationRefusalsByReason(testCase)
            % REPORT-ONLY. Dab's survivor census shows all of its
            % stimulus_presentation UNFOLDED, whereas Soph's e2e folded 173/175.
            % The second pass records a REASON per refused presentation
            % (Result.secondPass.stimulusSequence.refusals), and this surfaces
            % the histogram of those reasons -- which the corpus log did not.
            % It decides nothing (Operating Rule 4): whether "no responding
            % animal" (a genuine subject-less presentation, whose home is a bare
            % `timed_sequence` -- a team call) DOMINATES, or a different reason
            % (an unresolved-linkage bug the resolver should fix) does, is the
            % measurement this exists to take. Denominator asserted; the split
            % is report-only.
            r = testCase.Result.secondPass.stimulusSequence;
            testCase.assertTrue(isstruct(r) && isfield(r, 'presentations_read'), ...
                'the migrate result carries no stimulusSequence report');

            viaSibling = 0;
            if isfield(r, 'decomposed_via_epoch_sibling')
                viaSibling = r.decomposed_via_epoch_sibling;
            end
            viaStimulator = 0;
            if isfield(r, 'decomposed_via_stimulator')
                viaStimulator = r.decomposed_via_stimulator;
            end
            fprintf(['\n  STIMULUS-PRESENTATION FOLD (Dab, #31) -- report-only\n' ...
                     '    DENOMINATOR: %d presentation(s) read\n' ...
                     '    decomposed to timed_sequence_manipulation: %d\n' ...
                     '        animal via stimulus_response:      %d\n' ...
                     '        animal via epoch, own session (FORK 1): %d\n' ...
                     '        animal via stimulator element (no epoch element): %d\n' ...
                     '        animal via epoch, sibling session (FORK 2): %d\n' ...
                     '    refused (left as passthrough):             %d\n'], ...
                r.presentations_read, r.presentations_decomposed, ...
                r.decomposed_via_response, r.decomposed_via_epoch, ...
                viaStimulator, viaSibling, r.presentations_refused);

            % Histogram the refusal reasons. `refusals` is a cell of
            % struct('id', ..., 'reason', ...) appended once per refusal.
            counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for k = 1:numel(r.refusals)
                why = r.refusals{k}.reason;
                if isempty(why); why = '(empty reason)'; end
                if isKey(counts, why)
                    counts(why) = counts(why) + 1;
                else
                    counts(why) = 1;
                end
            end
            ks = keys(counts);
            if isempty(ks)
                fprintf('        (no refusals recorded)\n');
            else
                for i = 1:numel(ks)
                    fprintf('        %6d  %s\n', counts(ks{i}), ks{i});
                end
            end

            % FORK 1 is LIVE: it attributes a response-less presentation to the
            % animal recorded in its OWN session-scoped epoch (the `via epoch,
            % own session` line). THE STIMULATOR ROUTE is LIVE (Jess Haley,
            % 2026-10-21, PR #1021): when the own session-epoch records no
            % element, the presentation's `stimulus_element_id` -> stimulator
            % element -> its v1 subject. On Dab the 68 presentations fork 1
            % cannot attribute are recorded epochs with no sorted unit (Dab
            % writes element_epoch only for sorted units), NOT session-id gaps;
            % the stimulator route resolves all 68 in the research read. FORK 2
            % is MEASURED AND DISARMED (2026-08-25): cross-session it gives 2-12
            % sibling subjects and the true animal for none of the 68, so `via
            % epoch, sibling session` reads 0. The residual is characterised by
            % the reasons below; a refusal for "no grating parameter" means an
            % animal WAS resolved but the stimuli are not gratings -- a
            % separate, non-visual gap (#48).

            % Denominator only: a run that read zero presentations would make
            % the histogram a statement about nothing. Dab holds 1242 of them.
            verifyGreaterThan(testCase, r.presentations_read, 0, ...
                ['the second pass read 0 stimulus_presentation bodies, so the ' ...
                 'refusal histogram describes nothing -- Dab holds 1242']);
        end

        function testWhatTheStimulusPresentationParametersActuallyAre(testCase)
            % REPORT-ONLY. Dabrowska's only stimulator probe is the drug `bath`
            % (probeTable type 'stimulator'), so its stimulus_presentation are
            % pharmacological, not visual -- yet 1011 tripped isGratingParameters
            % (ANY one of angle/orientation/sf/tf present, non-empty). This dumps
            % the ACTUAL parameter field-name sets across every stimulus, and the
            % value ranges of the grating-named fields, so what the decoder wrote
            % is SEEN rather than inferred: a real grating carries angle+sf+tf
            % with varied values; a bath event mistyped as one carries a stray or
            % constant field. It decides nothing (Rule 4). The parse mirrors
            % stimulusArray/stimParameters so the sets match what the fold saw.
            gratingNames = {'angle', 'orientation', 'sFrequency', ...
                'spatial_frequency', 'sf', 'tFrequency', 'temporal_frequency', 'tf'};
            fieldSets = containers.Map('KeyType', 'char', 'ValueType', 'double');
            gCount    = containers.Map('KeyType', 'char', 'ValueType', 'double');
            gVals     = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for g = 1:numel(gratingNames); gCount(gratingNames{g}) = 0; end
            nPres = 0; nStim = 0;

            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                if ~(isfield(j, 'document_class') && isfield(j.document_class, 'class_name') ...
                        && strcmp(j.document_class.class_name, 'stimulus_presentation'))
                    continue;
                end
                nPres = nPres + 1;
                if ~isfield(j, 'stimulus_presentation') ...
                        || ~isfield(j.stimulus_presentation, 'stimuli')
                    continue;
                end
                raw = j.stimulus_presentation.stimuli;
                stims = {};
                if isstruct(raw)
                    for i = 1:numel(raw); stims{end+1} = raw(i); end %#ok<AGROW>
                elseif iscell(raw)
                    stims = raw;
                end
                for i = 1:numel(stims)
                    s = stims{i};
                    if ~(isstruct(s) && isscalar(s) && isfield(s, 'parameters') ...
                            && isstruct(s.parameters) && isscalar(s.parameters))
                        continue;
                    end
                    nStim = nStim + 1;
                    p = s.parameters;
                    fns = sort(fieldnames(p));
                    key = strjoin(reshape(fns, 1, []), ',');
                    if isKey(fieldSets, key); fieldSets(key) = fieldSets(key) + 1; ...
                    else; fieldSets(key) = 1; end
                    for g = 1:numel(gratingNames)
                        gn = gratingNames{g};
                        if isfield(p, gn) && ~isempty(p.(gn))
                            gCount(gn) = gCount(gn) + 1;
                            v = p.(gn);
                            if isnumeric(v) && isscalar(v)
                                if isKey(gVals, gn); acc = gVals(gn); else; acc = []; end
                                acc(end+1) = v; %#ok<AGROW>
                                gVals(gn) = acc;
                            end
                        end
                    end
                end
            end

            fprintf('\n  STIMULUS-PARAMETER CENSUS (Dab, #31) -- report-only\n');
            fprintf(['    DENOMINATOR: %d stimulus_presentation, %d stimulus(i) ' ...
                     'with a scalar parameters struct\n'], nPres, nStim);
            fprintf('    distinct parameter field-name set(s): %d\n', fieldSets.Count);
            ksets = keys(fieldSets);
            counts = cell2mat(values(fieldSets));
            [~, ord] = sort(counts, 'descend');
            for i = 1:min(numel(ksets), 25)
                kk = ksets{ord(i)};
                fprintf('        %6d  {%s}\n', fieldSets(kk), kk);
            end
            fprintf('    grating-named field presence + value range:\n');
            anyGrating = false;
            for g = 1:numel(gratingNames)
                gn = gratingNames{g};
                if gCount(gn) == 0; continue; end
                anyGrating = true;
                if isKey(gVals, gn) && ~isempty(gVals(gn))
                    vv = gVals(gn);
                    fprintf('        %-20s present %6d   distinct-values %d   min %g   max %g\n', ...
                        gn, gCount(gn), numel(unique(vv)), min(vv), max(vv));
                else
                    fprintf('        %-20s present %6d   (non-numeric / non-scalar values)\n', ...
                        gn, gCount(gn));
                end
            end
            if ~anyGrating
                fprintf('        (no grating-named field present on any stimulus)\n');
            end

            verifyGreaterThan(testCase, nPres, 0, ...
                'no stimulus_presentation bodies read -- census describes nothing');
        end

    end
end

% ===================== harness ============================================

function tf = etaEnabled()
v = getenv('NDI_TEST_ETA');
tf = ~isempty(v) && ~any(strcmpi(v, {'0','false','no'}));
end

function corpusDir = ensureDabCorpus()
%ENSUREDABCORPUS Download (once) and extract Dab.zip.
%   Same URL shape and cache layout as the PRED / 20211116 / Soph helpers.
%   Dab.zip is ~35 MB, so the download is quick; the migration + the
%   ontologyRowSubjects fan-out at scale are why this is a dispatched job.
corpusURL = 'https://ndi-programming-development.s3.us-east-1.amazonaws.com/Dab.zip';
cacheRoot = fullfile(tempdir(), 'ndi-corpus-Dab');
corpusDir = fullfile(cacheRoot, 'Dab');
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~isfolder(cacheRoot); mkdir(cacheRoot); end
zipPath = fullfile(cacheRoot, 'Dab.zip');
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
% Fallback: the zip may extract the json documents to cacheRoot directly, or
% under a differently-named single subdirectory. Find the directory that
% actually holds *.json and use it, rather than skipping on a name guess.
if ~isempty(dir(fullfile(cacheRoot, '*.json')))
    corpusDir = cacheRoot;
    return;
end
sub = dir(cacheRoot);
sub = sub([sub.isdir] & ~ismember({sub.name}, {'.','..'}));
for k = 1:numel(sub)
    candidate = fullfile(cacheRoot, sub(k).name);
    if ~isempty(dir(fullfile(candidate, '*.json')))
        corpusDir = candidate;
        return;
    end
end
error('ndi:corpus:noDir', ...
    'Dab.zip did not extract any directory holding *.json under %s', cacheRoot);
end

function bodies = readCorpusBodies(corpusDir)
%READCORPUSBODIES Every v1 document in the corpus, as JSON text.
%   `._` sidecars are macOS resource forks the zip carries; skipping them is
%   what did2.validate.sourceCensus's own reader does.
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end
end

function buildV1Sqlite(tmpFile, bodies)
%BUILDV1SQLITE A did_v1 sqlite database holding BODIES.
%   The shape is `docs(doc_id, doc_idx, json_code, timestamp)` because that is
%   what did2.convert.readers.sqliteV1 issues (`SELECT json_code FROM docs`),
%   the same columns the real legacy backend writes.
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
% BULK INSERT IN ONE TRANSACTION -- one fsync per row outside a transaction is
% pathological at scale (the Soph run #1 timeout). Throwaway fixture DB, so
% drop the per-write durability guarantees too.
mksqlite(dbid, 'PRAGMA synchronous = OFF');
mksqlite(dbid, 'PRAGMA journal_mode = MEMORY');
mksqlite(dbid, 'BEGIN TRANSACTION');
for k = 1:numel(bodies)
    docId = sprintf('id_%06d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
mksqlite(dbid, 'COMMIT');
end

function bodies = destinationBodies(dstPath)
%DESTINATIONBODIES Every document in the destination, as structs, read ONCE.
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end

function hits = findAllByClass(bodies, className)
hits = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if isfield(b,'document_class') && isfield(b.document_class,'class_name') ...
            && strcmp(b.document_class.class_name, className)
        hits{end+1} = b; %#ok<AGROW>
    end
end
end

function doc = findByClass(bodies, className)
doc = [];
hits = findAllByClass(bodies, className);
if ~isempty(hits); doc = hits{1}; end
end

function s = quarantineDiag(result)
if isempty(result.quarantine)
    s = ''; return;
end
n = numel(result.quarantine);
s = sprintf('%d document(s) quarantined; first %d:', n, min(5,n));
for i = 1:min(5,n)
    s = sprintf('%s\n    %s: %s', s, result.quarantine(i).class_name, ...
        result.quarantine(i).reason);
end
end

function s = resultDiag(result)
s = sprintf('[migrated %d, quarantined %d, edges %d] %s', ...
    result.summary.total, numel(result.quarantine), ...
    result.references.edges_examined, quarantineDiag(result));
end

function v = edgeOf(b, name)
%EDGEOF The value of one depends_on edge of a struct body, '' when absent.
v = '';
d = b.depends_on;
if iscell(d); d = [d{:}]; end
for k = 1:numel(d)
    if strcmp(d(k).name, name)
        if isfield(d(k), 'value'); v = d(k).value; else; v = d(k).document_id; end
        return;
    end
end
end
