classdef TestMigrateLocalEta20211116 < matlab.unittest.TestCase
%TESTMIGRATELOCALETA20211116 The 20211116 corpus through the WHOLE V_eta pipeline.
%
%   The second corpus to get the PRED treatment: migrate, open through
%   `ndi.session.dir`, and assert that NDI OBJECTS come back. PRED proved
%   the daq/sync spine; this one is chosen because it is the SMALLEST STEP
%   beyond it, measured rather than assumed (2026-08-14, read from the
%   corpus zips):
%
%       corpus         docs classes  NEW vs PRED   new docs
%       20211116       1220      21           13         1185
%       Dab           27561      26           17        26288
%       Soph         101427      32           24        99395
%
%   It shares 8 of PRED's 10 classes, so everything the vintage layer
%   already does is re-exercised, and its 13 new classes cluster into two
%   families plus one loner:
%
%       the stimulus-response tier   stimulus_response_scalar (273),
%                                    _parameters_basic (273),
%                                    stimulus_presentation (11),
%                                    control_stimulus_ids (11)
%       the calculator tier          hartley_calc (210), tuningcurve_calc
%                                    (84), oridirtuning_calc (42)
%       the epoch family             element_epoch (252)
%
%   WHAT THE UP-FRONT AUDIT SAID, so a reader knows what to expect rather
%   than discovering it from a red run. Of the 13 new classes only
%   `daqreader` is an NDI OBJECT type, and it is already in
%   ndi.vintage.map -- the others carry no `ndi_*_class` key and are data
%   documents. So the object layer needs little or nothing new here. The
%   risk is elsewhere:
%
%     * `element_epoch` documents carry an `epochid` BLOCK, and two NDI
%       readers index it by name -- `ndi.element` (the added-epoch branch)
%       and `ndi.daq.reader` (the ingested branch). V_eta drops `epochid`
%       for an `epoch_id` edge, so those are the frames most likely to
%       break first.
%     * the calculator fold is the one with history: dissolving a `_calc`
%       document instead of folding it 1->1 cost 11,448 orphans on Soph.
%       The orphan assertion below is that failure's regression test on a
%       corpus that actually holds calculators.
%
%   MIGRATION RUNS ONCE, in TestClassSetup, unlike PRED's per-method
%   `runPredMigrate`. At 14 documents re-migrating per method is free; at
%   1,220 it is 87x the work for no added coverage, and every method here
%   only READS the result.
%
%   SKIPS, NEVER FAILS, when the environment cannot support it: no
%   mksqlite, no NDI_TEST_ETA, no DID_SCHEMA_PATH, or no network for the
%   corpus. "Could not run" and "ran and found a defect" are different
%   findings and must not print the same result.

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
                testCase.CorpusDir = ensure20211116Corpus();
            catch ME
                assumeFail(testCase, sprintf( ...
                    'could not fetch the 20211116 corpus (%s); skipping.', ...
                    ME.message));
            end

            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));

            testCase.Bodies = readCorpusBodies(testCase.CorpusDir);
            buildV1Sqlite(fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite'), ...
                testCase.Bodies);

            testCase.Result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', true, 'TargetVersion', 'did_v2', 'Backup', false);
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

        function testTheStimulusFoldReportsItsSeveralAnimalCount(testCase)
            % REPORT-ONLY (Jess Haley, 2026-10-21): every corpus states how
            % many presentations resolve to SEVERAL animals in their session,
            % 0 included. Those become ONE distributive manipulation of the
            % session's cohort (stimulus plan, decision 2).
            r = testCase.Result.secondPass.stimulusSequence;
            testCase.assertTrue(isstruct(r) && isfield(r, 'several_animal_presentations'), ...
                'the stimulusSequence report carries no several-animal counter');
            ndi.unittest.migrate.printStimulusFoldReport(r, '20211116');
        end

        function testControlRecordsFoldIntoACovariateOrAreCounted(testCase)
            % Decided by Jess Haley, 2026-10-22 [control as covariate]: a v1
            % control_stimulus_ids about a folded presentation is read into
            % the `control condition` covariate (logical, XCO:0000099) of the
            % presentation's item value -- all false when v1 recorded NaN.
            % Amended 2026-10-26 [control pairing is a calculation]: the record
            % itself becomes a `calculation` (same id) when it can be placed
            % whole, and is otherwise carried as v1. The accounting must close:
            % every record read lands in exactly one bucket, and every record
            % is either a calculation or a v1 document in the destination.
            r = testCase.Result.secondPass.stimulusSequence;
            n = r.control_records_read;
            verifyEqual(testCase, n, 11, ...
                '20211116 holds 11 control_stimulus_ids documents');
            verifyEqual(testCase, n, r.control_records_folded + ...
                r.control_presentation_not_folded + r.control_no_position_map + ...
                r.control_unmappable + r.control_conflicting, ...
                'a control record fell into no bucket');
            sourceIds = {};
            for k = 1:numel(testCase.Bodies)
                b = testCase.Bodies{k};
                if ischar(b) || isstring(b)
                    if ~contains(char(b), '"control_stimulus_ids"'); continue; end
                    b = jsondecode(char(b));
                end
                if isstruct(b) && strcmp(b.document_class.class_name, 'control_stimulus_ids')
                    sourceIds{end+1} = char(b.base.id); %#ok<AGROW>
                end
            end
            verifyNumElements(testCase, sourceIds, n);
            dst = destinationBodies(testCase.Result.destination);
            withControl = 0; allFalse = 0; leftover = 0; converted = 0;
            for k = 1:numel(dst)
                d = dst{k};
                cls = d.document_class.class_name;
                if any(strcmp(char(d.base.id), sourceIds))
                    if strcmp(cls, 'control_stimulus_ids')
                        leftover = leftover + 1;
                    elseif strcmp(cls, 'calculation')
                        converted = converted + 1;
                    end
                end
                c = controlCovariate(d);
                if ~isempty(c)
                    withControl = withControl + 1;
                    if ~any(logical(c.logical(:))), allFalse = allFalse + 1; end
                end
            end
            verifyEqual(testCase, withControl, r.presentations_with_control_covariate, ...
                'every control covariate the pass counted reaches the destination');
            verifyEqual(testCase, allFalse, r.control_covariates_all_false);
            verifyEqual(testCase, converted, r.control_records_converted, ...
                'every converted control record is a calculation with its v1 id');
            verifyEqual(testCase, leftover + converted, n, ...
                'a control record is neither a calculation nor carried as v1');
            fprintf(['\n  CONTROL RECORDS (20211116): %d read; %d read into %d ' ...
                'presentation covariate(s) (%d all false); %d converted to a pairing ' ...
                'calculation; %d left as v1\n'], n, r.control_records_folded, ...
                r.presentations_with_control_covariate, r.control_covariates_all_false, ...
                converted, leftover);
        end

        function testTheWholeCorpusMigratesWithNothingQuarantinedOrDangling(testCase)
            % DENOMINATOR FIRST. A pass over zero documents quarantines
            % zero documents, and that reading prints the same digit as a
            % clean migration.
            verifyEqual(testCase, numel(testCase.Bodies), 1220, sprintf( ...
                ['the 20211116 corpus did not read as 1220 documents (got ' ...
                 '%d); every assertion here would be about a different ' ...
                 'corpus'], numel(testCase.Bodies)));
            verifyGreaterThan(testCase, testCase.Result.summary.total, 0, ...
                'the migration saw no documents at all');

            verifyEmpty(testCase, testCase.Result.quarantine, ...
                quarantineDiag(testCase.Result));

            % THE GRAPH CLOSES. This is the assertion the calculator family
            % exists to stress: folding a `_calc` document 1->1 preserves
            % its id so downstream references resolve, while DISSOLVING it
            % strands every reference to it. That mistake cost 11,448
            % orphans on Soph, and 20211116 is the smallest corpus that
            % holds calculators at all.
            verifyEqual(testCase, testCase.Result.references.orphan_count, 0, ...
                sprintf('the migrated graph does not close: %d orphan(s). %s', ...
                    testCase.Result.references.orphan_count, ...
                    resultDiag(testCase.Result)));
            verifyGreaterThan(testCase, testCase.Result.references.edges_examined, 0, ...
                ['the reference sweep examined 0 edges, so its 0 orphans ' ...
                 'is a statement about the sweep and not about the corpus']);
        end

        function testEveryDocumentThatDidNotConvertDidSoDeliberately(testCase)
            % THE GAP THE THREE ASSERTIONS ABOVE LEAVE OPEN, AND IT IS LARGE.
            % `0 quarantined` + `0 orphans` + `objects come back` says the
            % migration did not BREAK anything. It says nothing about whether
            % every document reached its DECIDED shape, because a migrator
            % that hands its input straight back is counted in
            % `migrated_count` -- nothing errored, nothing dangled, and the
            % document is a perfectly valid v1-class document that
            % did2.validate.silentLoss cannot see either. Measured on this
            % corpus before the assertion was written: 546 of 1220 documents
            % (45%) take that path, and no test in either repository named
            % the number.
            %
            % v1_to_v2 ALREADY COUNTS IT -- `unconverted_by_class`, per class,
            % at v1_to_v2.m:259 -- and its own comment says why the count is
            % the instrument rather than the code: a deliberate deferral and
            % an accidental fall-through are *indistinguishable downstream*,
            % so they are separated by EXPECTATION. That is what this test
            % supplies: the expectation, one declared row per class, each
            % with the reason it defers and the open item that will close it.
            %
            % WHAT IT ASSERTS AND WHAT IT DOES NOT. It asserts MEMBERSHIP in
            % BOTH directions -- an undeclared passthrough fails, and a
            % declared row that no longer fires fails too -- and it does NOT
            % pin the counts. The membership set is not a guess: no container
            % in this project has MATLAB, so each of the corpus's 21 classes
            % was checked by reading its guard and then evaluating that guard
            % against the real documents, off the corpus zip with python3:
            %
            %   DENOMINATOR: 21 distinct class(es) over 1220 document(s);
            %                10 have a `bodies = {preBody}` branch at all
            %     daqreader          3/3 carry `ndi_daqreader_class`      -> converts
            %     daqmetadatareader  1/1 carries class AND file parameter -> converts
            %     daqsystem          3/3 carry `ndi_daqsystem_class`      -> converts
            %     filenavigator      3/3 carry all four declarables       -> converts
            %     control_stimulus_ids 11/11 carry a populated
            %                        `stimulus_presentation_id`           -> converts
            %   the other 11 classes have no passthrough branch, so they cannot
            %   take one.
            %
            % The counts are left to the log rather than the assertion because
            % a count pin says "this many did not convert" where the membership
            % check says "and none of them was a surprise", and only the second
            % is a statement nobody has to re-derive after every schema change.
            % The breakdown prints UNCONDITIONALLY, green or red.
            s = testCase.Result.summary;

            % DENOMINATOR FIRST, unconditionally (Operating Rule 5). A
            % migration that saw nothing converts nothing, and prints the
            % same `unconverted: 0` as a migration that converted everything.
            fprintf(['\n  PASS-1 CONVERSION CENSUS (20211116)\n' ...
                     '    DENOMINATOR: %d document(s) read, %d migrated, ' ...
                     '%d quarantined\n' ...
                     '    unconverted (migrator returned its input): %d\n' ...
                     '    fragments (emitted, but hollow):           %d\n'], ...
                s.total, s.migrated_count, s.quarantine_count, ...
                s.unconverted_count, s.fragment_count);
            ndi.unittest.migrate.printClassTable(s.unconverted_by_class, '    unconverted');
            ndi.unittest.migrate.printClassTable(s.fragment_by_class,    '    fragment');

            verifyEqual(testCase, s.total, 1220, ...
                'the pass did not see 1220 documents; every figure here is about a different corpus');

            % A FRAGMENT IS NEVER DELIBERATE. Unlike a passthrough, it is a
            % document the migrator DID emit and that carries nothing --
            % the failure did2.validate.isFragment exists to catch. Recorded
            % 0 across all six corpora; asserted here rather than assumed.
            verifyEqual(testCase, s.fragment_count, 0, sprintf( ...
                ['%d document(s) migrated to a FRAGMENT. A passthrough is a ' ...
                 'deferral; a fragment is silent loss.'], s.fragment_count));

            % THE DECLARED DEFERRALS. Column 2 is the reason and the open
            % item, and it is the whole point of the row: a class listed
            % without one is a class nobody has thought about.
            declared = { ...
                'stimulus_response_scalar_parameters_basic', ...
                    ['unconditional passthrough (the migrator is `bodies = {preBody}` and ' ...
                     'says so: "Counted as `unconverted` by v1_to_v2, which is correct and ' ...
                     'intended"); the six parameters are re-attached by the ' ...
                     'did2.convert.resolveResponseParameters batch post-pass -- #61']; ...
                'stimulus_response_scalar', ...
                    ['THE EPOCH GATE, and it fires on every document: `element_epochid` is ' ...
                     'present on 273 of 273 here, and private/jEpochDocId.m answers '''' for ' ...
                     'EVERY did_v1 document by construction -- no source document carries an ' ...
                     '`epoch_id` edge and no migrator mints an `epoch`. Closes with #60''s ' ...
                     'migrator half, not before']; ...
                'stimulus_presentation', ...
                    ['deliberate passthrough; the decomposition needs the migrated-id graph ' ...
                     'and runs in the NDI second pass ' ...
                     '(internal/stimulusPresentationToItem) -- #31']; ...
                'syncrule', ...
                    ['a DEVICE-PAIR rule passes through pass 1 in its v1 form ' ...
                     '(DID-matlab +migrators_j/syncrule.m): the configuration names its ' ...
                     'two systems by edge, the v1 rule names them by NAME, and resolving ' ...
                     'a name to an id needs the batch. A channel-based rule is folded by ' ...
                     'did2.convert.resolveClockAlignment from DID-matlab #276 on (from/to ' ...
                     'acquisition_system edges, Jess Haley 2026-10-27 [sync configuration ' ...
                     'links its rigs]); before it, it survives to the final output (a ' ...
                     'gap printed by the survivor census)']; ...
                'control_stimulus_ids', ...
                    ['did-schema #88 deleted `control_designation` (#73 review item 67): ' ...
                     'the control is the `control condition` covariate of the item the ' ...
                     'presentation becomes ([control as covariate], Jess Haley 2026-10-22), ' ...
                     'built in the NDI stimulus fold, so the document passes through pass 1 ' ...
                     'under its v1 tombstone for that pass to consume (DID-matlab ' ...
                     '+migrators_j/control_stimulus_ids.m)']; ...
                'treatment', ...
                    ['carried whole as v1 by [one correct reading] and [dataset audit ' ...
                     'batch 1 and 2] (4) (Jess Haley, 2026-10-26): the two treatments ' ...
                     '("natural right / left eye opening", EMPTY:10000009 / EMPTY:10000008, ' ...
                     'no number) state no reading by themselves -- not a term that ' ...
                     'states its number''s kind, not a ChEBI substance -- so DID-matlab ' ...
                     '+migrators_j/treatment.m carries them with a needs_mapping note']};
            % `tuningcurve_calc` left on 2026-10-28: DID-matlab #272 ([tuning best
            % value is a condition], Jess Haley) rebuilds the stimids from the
            % conditions, so all 84 here convert (the deferral no longer fired).
            % `syncgraph` and `subject` were declared here before the #88 port
            % (DID-matlab #218); both now convert in pass 1 (e2e run
            % 39668356516: "2 of 5 declared deferral(s) no longer fire").

            ndi.unittest.migrate.verifyDeferralsAreDeclared(testCase, ...
                s.unconverted_by_class, declared);
        end

        function testNoV1DocumentSurvivesUnfoldedInTheFinalOutput(testCase)
            % THE BAR-2 INSTRUMENT. The census above counts what the SINGLE-
            % DOCUMENT migrators did in pass 1; it cannot see the SECOND PASSES
            % that run afterward (epochMint's armed folds, resolveResponseParameters,
            % resolveStimulusPresentations), so a class that reads "unconverted"
            % there can still reach its decided shape in the final DB. The only
            % sound test of "is this corpus fully at decided shape" is the FINAL
            % output: a v1 SOURCE class name that still labels a destination
            % document is a document that did not fold.
            %
            % REPORT-ONLY, DELIBERATELY, ON THIS FIRST LANDING. The pass
            % architecture has enough moving second passes that the surviving
            % set is worth MEASURING before it is asserted -- arming a gate
            % against a guessed set would either pass vacuously or fail on a
            % survivor that is actually persist-legitimate. It prints the
            % survivor census unconditionally (green or red on the rest of the
            % suite); the assertion arm lands once the set is read from a real
            % run and the folds that close it are built. Until then this method
            % cannot fail, which is stated rather than hidden.
            src = testCase.Bodies;
            dst = destinationBodies(testCase.Result.destination);
            survivors = ndi.unittest.migrate.finalV1SurvivorCensus( ...
                reshape(src, 1, []), reshape(dst, 1, []));

            fprintf(['\n  BAR-2 FINAL-OUTPUT V1 SURVIVOR CENSUS (20211116)\n' ...
                     '    DENOMINATOR: %d source document(s), %d destination ' ...
                     'document(s)\n' ...
                     '    v1 source class names still labelling a destination ' ...
                     'document: %d\n'], ...
                numel(src), numel(dst), numel(survivors));
            if isempty(survivors)
                fprintf('      (none -- every v1 class folded)\n');
            else
                for k = 1:numel(survivors)
                    note = 'UNFOLDED -- a Bar-2 gap unless persist';
                    if any(strcmp(survivors(k).class_name, {'subject', 'session'}))
                        note = 'persist (v1 class IS the V_eta class)';
                    end
                    fprintf('      %6d  %-24s %s\n', survivors(k).count, ...
                        survivors(k).class_name, note);
                end
            end
            % A denominator that read nothing is the silentLoss failure; assert
            % it even while the survivor set itself is report-only.
            verifyEqual(testCase, numel(src), 1220, ...
                'the source census did not read 1220 documents');
            verifyGreaterThan(testCase, numel(dst), 0, ...
                'the destination census read zero documents');
        end

        function testTheMigratedSessionOpensAndReadsBackThroughNDI(testCase)
            % The headline, same shape as PRED's. If this errors, nothing
            % below it is meaningful.
            assertTrue(testCase, isfile(testCase.Result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                testCase.Result.destination));

            % The fixture has no unique_reference.txt -- see the PRED test
            % for why only this one file is written and why reference.txt
            % deliberately is not.
            migrated = destinationBodies(testCase.Result.destination);
            % did-schema #88: the session is an `entity` of type session (T1)
            % whose base.id IS the session id.
            sessionDoc = findSessionEntity(migrated);
            assertNotEmpty(testCase, sessionDoc, ...
                'no entity of type session in the migrated database');
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), ...
                sessionDoc.base.id);

            s = ndi.session.dir(testCase.SessionRoot);
            assertTrue(testCase, isa(s, 'ndi.session.dir'), ...
                'ndi.session.dir did not return a session object');

            selected = ndi.database.fun.opendatabase( ...
                fullfile(testCase.SessionRoot, '.ndi'), s.id());
            assertTrue(testCase, isa(selected, ...
                'ndi.database.implementations.database.did2sqlite'), sprintf( ...
                'opendatabase chose a "%s", not a did2sqlite', class(selected)));

            % OBJECTS, not documents. Counts are not pinned to a literal
            % here the way PRED's are: PRED is 14 documents and hand
            % checkable, this is 1,220 and its class mix moves whenever a
            % fold changes. What must hold is that the object API returns
            % SOMETHING and that what it returns is the right type -- zero
            % is the pre-vintage symptom and is what this catches.
            devs = s.daqsystem_load();
            if isempty(devs); devs = {}; elseif ~iscell(devs); devs = {devs}; end
            verifyNotEmpty(testCase, devs, ...
                ['daqsystem_load returned nothing; 20211116 holds daqsystem ' ...
                 'documents, and zero is how a missed class rename reads']);
            for k = 1:numel(devs)
                verifyTrue(testCase, isa(devs{k}, 'ndi.daq.system'), sprintf( ...
                    'daqsystem_load returned a "%s"', class(devs{k})));
            end

            els = s.getelements();
            if isempty(els); els = {}; elseif ~iscell(els); els = {els}; end
            verifyNotEmpty(testCase, els, ...
                'getelements returned nothing; 20211116 holds element documents');
            for k = 1:numel(els)
                verifyTrue(testCase, isa(els{k}, 'ndi.element'), sprintf( ...
                    'getelements returned a "%s"', class(els{k})));
            end
        end

        function testTheAddedEpochTableIsReadableThroughTheObjectAPI(testCase)
            % A CHARACTERIZATION TEST, WRITTEN BEFORE THE #60 DISSOLUTION AND
            % DELIBERATELY ASSERTING TODAY'S BEHAVIOUR RATHER THAN THE SIGNED
            % ONE. It exists to be the gate that change is measured against.
            %
            % WHY IT IS NEEDED. `ndi.element.loadaddedepochs` appears in
            % exactly ONE file in this repository -- element.m itself:
            %
            %     $ grep -rln "loadaddedepochs" --include=*.m tests/ src/
            %     src/ndi/+ndi/element.m
            %
            % Zero tests. The method above this one opens the migrated
            % session and calls `getelements`, and never touches the epoch
            % table, so the whole added-epoch path has been unmeasured on
            % every corpus. That is the gap this closes: without it, #60
            % lands blind and the first evidence is somebody noticing the
            % spike epochs are gone.
            %
            % WHAT BREAKS UNDER THE DISSOLUTION, and it is three things at
            % once rather than the one the file header names:
            %
            %     element.m:459  if isfield(...document_properties,'element_epoch')
            %     element.m:463      newet.epoch_id = ...epochid.epochid;
            %     element.m:468      clocks_array = ...element_epoch.clocks;
            %
            % The GATE at :459 is the worst of the three: once the block is
            % gone the loop matches nothing, `et_added` comes back empty, and
            % every derived element reports NO epochs -- silently, with no
            % error, which is the shape this project keeps paying for.
            %
            % THE POPULATION, read from the corpus rather than quoted:
            %
            %     DENOMINATOR: 1220 json file(s); 23 element, 252 element_epoch
            %       element.direct == false : 21   <- these have epoch tables
            %       element.direct == true  :  2   (n-trode, stimulator)
            %       21 derived x 12 (session,epochid) pairs = 252, exact
            %
            % `buildepochtable` returns early for a DIRECT element, so the 2
            % probes are correctly expected to have no added epochs and are
            % excluded rather than counted as failures.
            %
            % STATUS: NEVER RUN when written -- there is no MATLAB in the
            % environment it was authored in. A first red run is as likely to
            % be this test being wrong as the code being wrong; the counts are
            % derived from the SOURCE bodies below rather than hard-coded, and
            % every failure prints its actuals, so the first run can settle
            % which it is without a second round trip.
            assertTrue(testCase, isfile(testCase.Result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                testCase.Result.destination));

            % The expected epoch ids come from the V1 SOURCE, not from a
            % literal and not from the migrated output -- an assertion built
            % from the migration's own result cannot catch the migration.
            % `testCase.Bodies` holds JSON TEXT, not structs -- see
            % readCorpusBodies at the foot of this file. `jsondecode` is the
            % idiom every other method here uses, and the first draft of this
            % one indexed the char arrays as structs.
            expectedEpochIds = {};
            derivedSourceElements = 0;
            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                if ~isfield(j, 'document_class') ...
                        || ~isfield(j.document_class, 'class_name')
                    continue;
                end
                cn = j.document_class.class_name;
                if strcmp(cn, 'element_epoch') && isfield(j, 'epochid') ...
                        && isfield(j.epochid, 'epochid') && ~isempty(j.epochid.epochid)
                    expectedEpochIds{end+1} = char(j.epochid.epochid); %#ok<AGROW>
                elseif strcmp(cn, 'element') && isfield(j, 'element') ...
                        && isfield(j.element, 'direct') && ~j.element.direct
                    derivedSourceElements = derivedSourceElements + 1;
                end
            end
            expectedEpochIds = unique(expectedEpochIds);

            % DENOMINATOR FIRST, UNCONDITIONALLY (rule 5). A run where the
            % source scan found nothing must say so rather than pass by
            % asserting nothing -- the silentLoss defect exactly.
            fprintf(['\n  ADDED-EPOCH CHARACTERIZATION\n' ...
                     '    DENOMINATOR: %d source body(ies) read; %d derived ' ...
                     '(direct==false) element(s); %d distinct epoch id(s)\n'], ...
                numel(testCase.Bodies), derivedSourceElements, ...
                numel(expectedEpochIds));
            assertNotEmpty(testCase, expectedEpochIds, ...
                ['no epoch ids found in the SOURCE bodies -- this test ' ...
                 'measured nothing, which is not a pass']);
            assertGreaterThan(testCase, derivedSourceElements, 0, ...
                ['no derived (direct==false) elements in the source -- ' ...
                 'nothing here can exercise loadaddedepochs']);

            s = ndi.session.dir(testCase.SessionRoot);
            els = s.getelements();
            if isempty(els); els = {}; elseif ~iscell(els); els = {els}; end
            assertNotEmpty(testCase, els, ...
                'getelements returned nothing, so no epoch table can be read');

            % ONLY THE DERIVED ELEMENTS ARE DRIVEN, mirroring
            % buildepochtable's own early return for a DIRECT element. The
            % two probes here (n-trode, stimulator) are direct, and their
            % epoch table comes from the daq system and file navigator rather
            % than from added-epoch documents -- a path that needs
            % acquisition files the corpus zips do not carry (measured
            % 2026-08-14: 0 non-JSON files in 20211116). Driving them would
            % test the absence of the fixture, not the read path.
            %
            % ERRORS ARE COLLECTED, NOT THROWN, so one bad element cannot
            % abort the loop and take the denominator print with it. A
            % characterization test that dies before reporting has measured
            % nothing, and "it errored" and "it returned empty" are different
            % findings that must not arrive as the same silence.
            withEpochs = 0;
            derivedDriven = 0;
            seenEpochIds = {};
            pairCount = 0;
            failures = {};
            for k = 1:numel(els)
                if els{k}.direct
                    continue;
                end
                derivedDriven = derivedDriven + 1;
                try
                    et = els{k}.epochtable();
                catch epochErr
                    failures{end+1} = sprintf('%s: %s', ...
                        els{k}.elementstring(), epochErr.message); %#ok<AGROW>
                    continue;
                end
                pairCount = pairCount + numel(et);
                if ~isempty(et)
                    withEpochs = withEpochs + 1;
                    seenEpochIds = [seenEpochIds, {et.epoch_id}]; %#ok<AGROW>
                end
            end

            fprintf(['    MEASURED: %d derived element object(s) driven of ' ...
                     '%d returned; %d returned a non-empty epoch table; ' ...
                     '%d (element,epoch) pair(s); %d distinct epoch id(s); ' ...
                     '%d ERRORED\n'], ...
                derivedDriven, numel(els), withEpochs, pairCount, ...
                numel(unique(seenEpochIds)), numel(failures));

            verifyEmpty(testCase, failures, sprintf( ...
                ['epochtable() raised on %d derived element(s):\n      %s'], ...
                numel(failures), strjoin(failures, sprintf('\n      '))));

            % THE ASSERTION THAT MATTERS. Zero is the pre-vintage symptom and
            % is exactly what the dissolution would produce.
            verifyGreaterThan(testCase, withEpochs, 0, sprintf( ...
                ['NO element returned an epoch table. The source holds %d ' ...
                 'derived element(s) and %d distinct epoch id(s), so this ' ...
                 'is the added-epoch read path returning empty -- the ' ...
                 'element.m:459 `isfield(...,''element_epoch'')` gate is ' ...
                 'the first place to look.'], ...
                derivedSourceElements, numel(expectedEpochIds)));

            % Every epoch id the object layer reports must be one the SOURCE
            % carried. A rebuilt-but-invented id would satisfy the count
            % assertion above and mean the table was reconstructed wrongly.
            unexpected = setdiff(unique(seenEpochIds), expectedEpochIds);
            verifyEmpty(testCase, unexpected, sprintf( ...
                ['the epoch table reports %d id(s) the v1 source never ' ...
                 'carried: %s'], numel(unexpected), strjoin(unexpected, ', ')));
        end

        function testTheEpochFamilyDissolvesIntoPerEpochTrains(testCase)
            % UPDATED 2026-10-26. Decided by Jess Haley, 2026-10-22 [epoch
            % dissolution before merge] (F1): each v1 element_epoch becomes ONE
            % observation of its element per epoch (base.id preserved, variable
            % GO:0001508 for a `spikes` element) owning one data body (its
            % .vhsb). AMENDED by [device clocks on one epoch] (Jess Haley,
            % 2026-10-26): each epoch extent is tied to its acquisition system,
            % and an extent that cannot be tied to EXACTLY ONE system mints
            % nothing; did2.convert.epochMint lists its source as carried
            % (epoch_extent_carried_source_ids) and resolveEpochProbemap keeps
            % that acquisition_epoch whole. So every source element_epoch is
            % EITHER a spike-train observation owning a body OR carried whole
            % under that rule, and every surviving acquisition_epoch is one of
            % the carried ones.
            migrated = destinationBodies(testCase.Result.destination);
            srcIds = {};
            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                if isfield(j, 'document_class') && isfield(j.document_class, 'class_name') ...
                        && strcmp(j.document_class.class_name, 'element_epoch')
                    srcIds{end+1} = char(j.base.id); %#ok<AGROW>
                end
            end
            mint = testCase.Result.secondPass.epochMint;
            carriedIds = {};
            if isstruct(mint) && isfield(mint, 'epoch_extent_carried_source_ids')
                carriedIds = cellstr(mint.epoch_extent_carried_source_ids);
            end
            left = findAllByClass(migrated, 'acquisition_epoch');
            leftIds = cellfun(@(d) char(d.base.id), left, 'UniformOutput', false);
            byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
            owned = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for k = 1:numel(migrated)
                byId(char(migrated{k}.base.id)) = migrated{k};
                c = migrated{k}.document_class.class_name;
                if any(strcmp(c, {'opaque_body', 'sampled_body'}))
                    ow = depValues(migrated{k}, 'owner_id');
                    for j = 1:numel(ow); owned(ow{j}) = true; end
                end
            end
            asTrain = 0; withBody = 0; carried = 0; neither = {};
            for k = 1:numel(srcIds)
                if any(strcmp(srcIds{k}, carriedIds)) && any(strcmp(srcIds{k}, leftIds))
                    carried = carried + 1;
                    continue;
                end
                if isKey(byId, srcIds{k})
                    d = byId(srcIds{k});
                    if strcmp(d.document_class.class_name, 'observation') ...
                            && isfield(d, 'statement') ...
                            && strcmp(char(d.statement.variable.node), 'GO:0001508')
                        asTrain = asTrain + 1;
                        withBody = withBody + isKey(owned, srcIds{k});
                        continue;
                    end
                end
                neither{end+1} = srcIds{k}; %#ok<AGROW>
            end
            fprintf(['\n  EPOCH DISSOLUTION\n    DENOMINATOR: %d v1 element_epoch ' ...
                'document(s)\n    spike-train observations: %d (owning a body: %d)\n' ...
                '    carried whole by [device clocks on one epoch] (no one system): %d\n' ...
                '    acquisition_epoch in the destination: %d\n'], numel(srcIds), ...
                asTrain, withBody, carried, numel(left));
            assertNotEmpty(testCase, srcIds, 'no element_epoch in the source: measured nothing');
            verifyEmpty(testCase, neither, sprintf(['%d element_epoch(s) are neither a ' ...
                'spike-train observation nor carried by [device clocks on one epoch]'], ...
                numel(neither)));
            verifyEqual(testCase, withBody, asTrain, ...
                'every spike-train observation must own its body');
            verifyEmpty(testCase, setdiff(leftIds, carriedIds), ...
                'an acquisition_epoch survived that epochMint did not list as carried');
            verifyEmpty(testCase, findAllByClass(migrated, 'element_epoch'), ...
                'element_epoch documents survived migration under the v1 name');
        end

        function testNoHartleyPresentationIsRefusedForItsGeneratorKeys(testCase)
            % INVERTED 2026-10-30 from
            % testTheHartleyPresentationsAreCarriedAndTheGratingRunIsNot.
            % Decided by Jess Haley, 2026-10-30 [Hartley settings on the
            % inline method] (did-schema V_eta_go_forward_class_audit.md,
            % G35): a generator key the shared basis does not read is a
            % parameter of the presentation manipulation's inline method, so
            % none of the ten Hartley presentations is refused under carry-080
            % for it any more -- except one that becomes a STANDALONE item
            % (no subject), which has no method to hold them. Whether each
            % Hartley presentation then folds (subject, epoch anchor) is
            % printed, not pinned: no run of this branch has measured it.
            [srcPres, hartley] = presentationIds(testCase.Bodies);
            verifyEqual(testCase, numel(srcPres), 11, sprintf( ...
                ['the corpus did not read as 11 stimulus_presentation ' ...
                 'documents (got %d); every count below would be about ' ...
                 'something else'], numel(srcPres)));
            verifyEqual(testCase, numel(hartley), 10, ...
                '20211116 holds 10 Hartley generator presentations');
            r = testCase.Result.secondPass.stimulusSequence;
            for k = 1:numel(r.refusals)
                f = r.refusals{k};
                if ~any(strcmp(char(f.id), hartley)); continue; end
                if startsWith(char(f.reason), '[carry-080]')
                    verifySubstring(testCase, char(f.reason), 'standalone item', ...
                        sprintf(['Hartley presentation %s is still refused for ' ...
                        'its generator keys: %s'], char(f.id), char(f.reason)));
                end
            end
            migrated = destinationBodies(testCase.Result.destination);
            allIds = cellfun(@(d) string(d.base.id), migrated(:)');
            verifyTrue(testCase, all(ismember(string(srcPres), allIds)), ...
                'a stimulus_presentation id is missing from the destination');
            fprintf('\n  HARTLEY PRESENTATIONS (20211116): %d read, %d refused for unplaced keys\n', ...
                numel(hartley), r.presentations_refused_unplaced);
            for k = 1:numel(srcPres)
                hit = migrated(allIds == string(srcPres{k}));
                if isempty(hit); continue; end
                d = hit{1};
                fprintf('    %s: destination class %s\n', srcPres{k}, ...
                    d.document_class.class_name);
                % a folded Hartley manipulation carries its generator keys
                if any(strcmp(srcPres{k}, hartley)) ...
                        && strcmp(d.document_class.class_name, 'manipulation')
                    verifyTrue(testCase, hasInlineParameter(d, 'Random Seed'), ...
                        sprintf(['folded Hartley presentation %s has no ' ...
                        'Random Seed on its inline method'], srcPres{k}));
                end
            end
        end

        function testTheHartleyBasisIsMintedOnlyForAFoldedPresentation(testCase)
            % INVERTS testNoHartleyBasisIsMintedWhenNoPresentationIsDecomposed
            % ([Hartley settings on the inline method], Jess Haley,
            % 2026-10-30): the shared basis is minted only for a presentation
            % the pass folds, so the basis methods in the destination are
            % exactly the ones the pass reports, and there are some exactly
            % when a Hartley presentation folded.
            [~, hartley] = presentationIds(testCase.Bodies);
            verifyNumElements(testCase, hartley, 10);
            migrated = destinationBodies(testCase.Result.destination);
            methods = findAllByClass(migrated, 'method');
            nBasis = 0;
            for k = 1:numel(methods)
                if isfield(methods{k}, 'method') && isfield(methods{k}.method, 'term') ...
                        && strcmp(methods{k}.method.term.name, 'Hartley basis grating')
                    nBasis = nBasis + 1;
                end
            end
            verifyEqual(testCase, nBasis, ...
                testCase.Result.secondPass.stimulusSequence.shared_methods_minted);
            nFolded = 0;
            for k = 1:numel(migrated)
                d = migrated{k};
                if any(strcmp(char(d.base.id), hartley)) ...
                        && any(strcmp(d.document_class.class_name, {'manipulation', 'item'}))
                    nFolded = nFolded + 1;
                end
            end
            fprintf('\n  HARTLEY BASIS (20211116): %d presentation(s) folded, %d basis method(s)\n', ...
                nFolded, nBasis);
            verifyEqual(testCase, nBasis > 0, nFolded > 0, ...
                'basis methods are minted exactly when a Hartley presentation folds');
        end

        function testTheFrameTimesGoWithTheirPresentation(testCase)
            % AMENDED 2026-10-30 from testTheFrameTimesStayOnTheirV1Sources
            % ([Hartley settings on the inline method], Jess Haley,
            % 2026-10-30): a Hartley presentation may now fold. Each one is
            % EITHER an item manipulation (or a standalone item) with its frame
            % onsets as the 'onset time' covariate, OR carried as v1.
            [~, hartley] = presentationIds(testCase.Bodies);
            verifyNumElements(testCase, hartley, 10);
            migrated = destinationBodies(testCase.Result.destination);
            allIds = cellfun(@(d) string(d.base.id), migrated(:)');
            for k = 1:numel(hartley)
                hit = migrated(allIds == string(hartley{k}));
                verifyNotEmpty(testCase, hit, ...
                    sprintf('Hartley presentation %s is missing', hartley{k}));
                if isempty(hit); continue; end
                d = hit{1};
                cn = d.document_class.class_name;
                if strcmp(cn, 'stimulus_presentation')
                    verifyEqual(testCase, char(d.document_class.schema_version), ...
                        'did_v1', 'a carried presentation is stamped did_v1');
                else
                    verifyTrue(testCase, any(strcmp(cn, {'manipulation', 'item'})), ...
                        sprintf('Hartley presentation %s became a %s', hartley{k}, cn));
                    verifyTrue(testCase, hasCovariate(d, 'onset time'), ...
                        sprintf('folded Hartley presentation %s has no onset time', hartley{k}));
                end
            end
        end

        function testTheCalculatorFamilyKeepsItsIdentities(testCase)
            % The 1->1 fold's whole point: a calculator output keeps its
            % base.id so downstream references resolve. The orphan count
            % above is the systemic check; this one names the mechanism, so
            % a regression says WHICH property broke.
            srcIds = {};
            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                cn = '';
                if isfield(j,'document_class') && isfield(j.document_class,'class_name')
                    cn = j.document_class.class_name;
                end
                if any(strcmp(cn, {'tuningcurve_calc','oridirtuning_calc','hartley_calc'}))
                    srcIds{end+1} = j.base.id; %#ok<AGROW>
                end
            end
            verifyNotEmpty(testCase, srcIds, ...
                'no calculator documents found in the corpus to check');

            migrated = destinationBodies(testCase.Result.destination);
            dstIds = cellfun(@(d) string(d.base.id), migrated(:)');
            missing = srcIds(~ismember(string(srcIds), dstIds));
            verifyEmpty(testCase, missing, sprintf( ...
                ['%d of %d calculator id(s) are absent from the migrated ' ...
                 'set. A calculator that DISSOLVES loses its id and every ' ...
                 'downstream reference dangles -- the 11,448-orphan ' ...
                 'failure.'], numel(missing), numel(srcIds)));
        end

    end
end

% ===================== harness ============================================

function tf = etaEnabled()
v = getenv('NDI_TEST_ETA');
tf = ~isempty(v) && ~any(strcmpi(v, {'0','false','no'}));
end

function corpusDir = ensure20211116Corpus()
%ENSURE20211116CORPUS Download (once) and extract 20211116.zip.
%   Same URL shape and cache layout as the PRED helper, deliberately.
corpusURL = 'https://ndi-programming-development.s3.us-east-1.amazonaws.com/20211116.zip';
cacheRoot = fullfile(tempdir(), 'ndi-corpus-20211116');
corpusDir = fullfile(cacheRoot, '20211116');
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~isfolder(cacheRoot); mkdir(cacheRoot); end
zipPath = fullfile(cacheRoot, '20211116.zip');
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
if ~isfolder(corpusDir)
    error('ndi:corpus:noDir', ...
        'the zip did not extract a 20211116/ directory under %s', cacheRoot);
end
end

function bodies = readCorpusBodies(corpusDir)
%READCORPUSBODIES Every v1 document in the corpus, as JSON text.
%   `._` sidecars are macOS resource forks the zip carries; skipping them
%   is what did2.validate.sourceCensus's own reader does.
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end
end

function buildV1Sqlite(tmpFile, bodies)
%BUILDV1SQLITE A did_v1 sqlite database holding BODIES.
%   The shape is `docs(doc_id, doc_idx, json_code, timestamp)` because that
%   is what the reader asks for -- did2.convert.readers.sqliteV1 issues
%   `SELECT json_code FROM docs`, and the real legacy backend writes the
%   same columns (did/+implementations/sqlitedb.m: insert_into_table('docs',
%   'doc_id,json_code,timestamp', ...)). So this fixture is not a
%   simplification of the read path; it is the same column.
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
for k = 1:numel(bodies)
    docId = sprintf('id_%05d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
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

function [srcPres, hartley] = presentationIds(bodies)
%PRESENTATIONIDS The ids of the corpus's v1 stimulus_presentation documents,
%   and of those that are Hartley generators.
srcPres = {};
hartley = {};
for k = 1:numel(bodies)
    j = jsondecode(bodies{k});
    if isfield(j, 'document_class') && isfield(j.document_class, 'class_name') ...
            && strcmp(j.document_class.class_name, 'stimulus_presentation')
        srcPres{end+1} = char(j.base.id); %#ok<AGROW>
        if isHartleyGenerator(j)
            hartley{end+1} = char(j.base.id); %#ok<AGROW>
        end
    end
end
end

function tf = hasInlineParameter(d, variable)
%HASINLINEPARAMETER True when an interaction's inline method has a parameter
%   whose variable is named VARIABLE.
tf = false;
if ~isfield(d, 'interaction') || ~isfield(d.interaction, 'method') ...
        || ~isfield(d.interaction.method, 'parameters')
    return;
end
p = d.interaction.method.parameters;
if isstruct(p); p = num2cell(p); end
for k = 1:numel(p)
    if isstruct(p{k}) && isfield(p{k}, 'variable') && isstruct(p{k}.variable) ...
            && strcmp(char(p{k}.variable.name), variable)
        tf = true;
        return;
    end
end
end

function tf = hasCovariate(d, name)
%HASCOVARIATE True when the document has a covariate whose variable is NAME.
tf = false;
if ~isfield(d, 'data') || ~isstruct(d.data) || ~isfield(d.data, 'covariates'); return; end
cs = ndi.v2.entries(d.data.covariates);
for j = 1:numel(cs)
    v = cs{j}.variable;
    if iscell(v), v = v{1}; end
    if isstruct(v) && isfield(v, 'name') && strcmp(char(v.name), name)
        tf = true;
        return;
    end
end
end

function tf = isHartleyGenerator(j)
%ISHARTLEYGENERATOR A v1 stimulus_presentation whose stimuli carry the Hartley
%   generator keys (M, K_absmax, L_absmax, sfmax: newStimKind's hartleystim).
tf = false;
if ~isfield(j, 'stimulus_presentation') || ~isfield(j.stimulus_presentation, 'stimuli')
    return;
end
raw = j.stimulus_presentation.stimuli;
if isstruct(raw); raw = num2cell(raw); end
if ~iscell(raw); return; end
for k = 1:numel(raw)
    s = raw{k};
    if isstruct(s) && isfield(s, 'parameters') && isstruct(s.parameters) ...
            && all(isfield(s.parameters, {'M', 'K_absmax', 'L_absmax', 'sfmax'}))
        tf = true;
        return;
    end
end
end

function hits = itemManipulations(bodies)
%ITEMMANIPULATIONS The `manipulation` documents listing the `item` value kind
%   (did-schema #88: a statement is a direction class plus one value kind).
hits = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isfield(b, 'document_class') || ~strcmp(b.document_class.class_name, 'manipulation')
        continue;
    end
    sc = b.document_class.superclasses;
    if isstruct(sc) && any(strcmp({sc.class_name}, 'item'))
        hits{end+1} = b; %#ok<AGROW>
    end
end
end

function [v, u] = methodEntry(doc, variable)
%METHODENTRY A `method` document's parameter VARIABLE: value and unit name.
v = []; u = '';
if ~isfield(doc.method, 'parameters'); return; end
p = doc.method.parameters;
if isstruct(p); p = num2cell(p); end
for k = 1:numel(p)
    e = p{k};
    if strcmp(e.variable.name, variable)
        if isfield(e, 'quantity') && ~isempty(e.quantity); v = e.quantity.value; end
        if isfield(e, 'unit') && isstruct(e.unit) && ~isempty(e.unit); u = e.unit.name; end
        return;
    end
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

function doc = findSessionEntity(bodies)
%FINDSESSIONENTITY The `entity` of type session (did-schema #88, T1).
doc = [];
for k = 1:numel(bodies)
    d = bodies{k};
    if isstruct(d) && isfield(d, 'document_class') ...
            && strcmp(d.document_class.class_name, 'entity') ...
            && isfield(d, 'entity') && isfield(d.entity, 'type') ...
            && isfield(d.entity.type, 'name') && ndi.v2.vocabIs('entity_type', d.entity.type, 'session')
        doc = d;
        return;
    end
end
end

function c = controlCovariate(d)
%CONTROLCOVARIATE The document's `control condition` covariate, or [].
c = [];
if ~isfield(d, 'data') || ~isstruct(d.data) || ~isfield(d.data, 'covariates'); return; end
cs = ndi.v2.entries(d.data.covariates);
for j = 1:numel(cs)
    v = cs{j}.variable;
    if iscell(v), v = v{1}; end
    if isstruct(v) && isfield(v, 'name') && strcmp(char(v.name), 'control condition')
        c = cs{j};
        return;
    end
end
end

function v = depValues(b, name)
v = {};
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~strcmp(char(d.name), name); continue; end
    if isfield(d, 'value') && ~isempty(d.value); v{end+1} = char(d.value); %#ok<AGROW>
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); v{end+1} = char(d.document_id); end %#ok<AGROW>
end
end
