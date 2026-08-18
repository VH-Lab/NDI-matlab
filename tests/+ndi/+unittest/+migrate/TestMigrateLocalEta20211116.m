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
                'Validate', true, 'TargetVersion', 'V_eta', 'Backup', false);
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
                     '(internal/stimulusPresentationToTimedSequence) -- #31']; ...
                'syncgraph', ...
                    ['THE SESSION GATE, and like the epoch gate it fires on every document: ' ...
                     '+migrators_j/syncgraph.m says of `jSessionDocId` that it "answers '''' ' ...
                     'by construction in pass 1 -- the same shape as jEpochDocId". Closes when ' ...
                     'the fold moves into the batch phase; the branch that will run is ' ...
                     'already driven by testSyncgraphFoldsWhenTheSessionResolves']; ...
                'syncrule', ...
                    ['no device pair to name. Both v1 documents here carry ' ...
                     '`parameters.number_fullpath_matches` and NO `daqsystem1_name`, so ' ...
                     'jAcquisitionChannels returns [] for both halves -- "NO DEVICE => NO ' ...
                     'DOCUMENT" -- and an `acquisition_channels` edge that named nothing ' ...
                     'would be the invented-empty-edge defect. A filematch rule genuinely ' ...
                     'has no device pair; this is the source being honest, not a gap']; ...
                'subject', ...
                    ['PERSIST, NOT A DEFERRAL -- the one row here that is not owed any ' ...
                     'future work. A v1 `subject` IS the V_eta `subject` (persist), and ' ...
                     '+migrators_j/subject.m only fills `local_identifier` when it is ' ...
                     'empty; this corpus''s subject already carries one, so the migrator ' ...
                     'returns its input and the census counts it as "unconverted". That is ' ...
                     'the census being literal: "migrator returned its input" spans both a ' ...
                     'deferral and a correct identity migration, and only the declared ' ...
                     'reason tells them apart. If `local_identifier` were empty the ' ...
                     'migrator would fill it, the body would change, and this row would ' ...
                     'not appear -- so its APPEARANCE is proof the handle was already set']};

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

        function testTheEpochFamilyMigratesAndIsReachable(testCase)
            % `element_epoch` (252 documents) is the class PRED does not
            % have, and it is the reason this corpus is the next step. Its
            % v1 documents carry an `epochid` BLOCK that two NDI readers
            % index by name; V_eta drops `epochid` for an `epoch_id` edge.
            migrated = destinationBodies(testCase.Result.destination);
            epochs = findAllByClass(migrated, 'acquisition_epoch');
            verifyNotEmpty(testCase, epochs, ...
                ['no `acquisition_epoch` documents in the destination. ' ...
                 '20211116 holds 252 `element_epoch` documents, which is ' ...
                 'what that class is renamed from -- zero here means the ' ...
                 'rename did not happen or the class moved again.']);
            % NOTHING SURVIVES UNDER THE V1 NAME. A migration that emitted
            % both would double-count every epoch.
            verifyEmpty(testCase, findAllByClass(migrated, 'element_epoch'), ...
                'element_epoch documents survived migration under the v1 name');
        end

        function testEveryStimulusPresentationIsDecomposedAroundItsPreservedId(testCase)
            % THE SIGNED STIMULUS MODEL, on the only corpus that holds it.
            % Read from the corpus rather than quoted: 11
            % stimulus_presentation documents, 1 enumerating 225 stimuli and
            % 10 carrying a Hartley GENERATOR recipe that enumerates nothing.
            srcPres = {};
            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                if isfield(j, 'document_class') ...
                        && isfield(j.document_class, 'class_name') ...
                        && strcmp(j.document_class.class_name, 'stimulus_presentation')
                    srcPres{end+1} = j.base.id; %#ok<AGROW>
                end
            end
            verifyEqual(testCase, numel(srcPres), 11, sprintf( ...
                ['the corpus did not read as 11 stimulus_presentation ' ...
                 'documents (got %d); every count below would be about ' ...
                 'something else'], numel(srcPres)));

            migrated = destinationBodies(testCase.Result.destination);
            seqs = findAllByClass(migrated, 'timed_sequence_manipulation');
            % THIS DIAGNOSTIC USED TO END "so a shortfall is a refusal to
            % read, not a crash." IT WAS WRONG, AND IT COST A ROUND TRIP.
            % The pass was throwing on EVERY call -- a signature/arguments
            % mismatch, so not one line of it executed -- and
            % `resolveStimulusPresentations` is wrapped in a try/catch that
            % warns and falls back to passthrough. A reader who believed
            % the old sentence went looking at the refusal guards, which
            % had never run.
            %
            % ZERO IS THE ONE VALUE THAT CANNOT DISTINGUISH THEM, so the
            % text now says what to check instead of asserting which it is.
            % That is this project's own rule -- "nobody looked" is a third
            % state -- applied to a test's own diagnostic.
            verifyEqual(testCase, numel(seqs), 11, sprintf( ...
                ['%d of 11 presentations became a ' ...
                 'timed_sequence_manipulation. TWO CAUSES PRODUCE THIS ' ...
                 'AND THEY LOOK IDENTICAL FROM HERE: a per-presentation ' ...
                 'REFUSAL (no responding animal, or stimuli that cannot ' ...
                 'be typed), or the whole pass THROWING -- ' ...
                 'ndi.migrate.local wraps resolveStimulusPresentations in ' ...
                 'a try/catch that warns and leaves everything as ' ...
                 'passthrough. Read the run log for "Second-pass ' ...
                 'stimulus_presentation decomposition failed" FIRST; a ' ...
                 'refusal names its reason per presentation, a throw ' ...
                 'names a file and a line.'], ...
                numel(seqs)));

            % THE ID IS PRESERVED, WHICH IS THE WHOLE MODEL. 494 inbound
            % edges point at these 11 ids on this corpus (273
            % stimulus_response_scalar + 210 hartley_calc + 11
            % control_stimulus_ids); reassigning one dangles all of them,
            % which is the 11,448-orphan failure in a different family.
            dstIds = cellfun(@(d) string(d.base.id), seqs(:)');
            verifyTrue(testCase, all(ismember(string(srcPres), dstIds)), ...
                ['a stimulus_presentation id is missing from the ' ...
                 'timed_sequence_manipulation set -- the decomposition ' ...
                 'reassigned an id instead of preserving it']);

            % and NOTHING survives under the v1 name or under the superseded
            % flattened one
            verifyEmpty(testCase, findAllByClass(migrated, 'stimulus_presentation'), ...
                'stimulus_presentation documents survived the decomposition');
            verifyEmpty(testCase, ...
                findAllByClass(migrated, 'visual_grating_manipulation'), ...
                ['a visual_grating_manipulation was emitted. That pass is ' ...
                 'GATED OFF: it is retained only for the presentation-less ' ...
                 'single-grating case, and both emitters claim the same ' ...
                 'base.id.']);
        end

        function testTheHartleyBasisIsMintedOnceAndCarriesItsPhase(testCase)
            % The enumeration lives in the `hartley_calc` documents, not in
            % the presentations: hartley_numbers {S,KXV,KYV,ORDER} is 3360
            % entries and has ONE distinct value across all 210 of them --
            % 1680 (kx,ky) pairs x 2 signs, 41*41-1 = 1680 exactly, the DC
            % term excluded. So ONE basis set serves all ten presentations.
            migrated = destinationBodies(testCase.Result.destination);
            gratings = findAllByClass(migrated, 'visual_grating');
            verifyNotEmpty(testCase, gratings, ...
                ['no standalone visual_grating documents. Either the basis ' ...
                 'was not assembled or `visual_grating` is abstract again ' ...
                 '(it stopped being abstract on 2026-08-17).']);

            % MINTED ONCE: 3360 for the Hartley basis + the distinct gratings
            % of the single 225-stimulus enumerated presentation. Ten copies
            % of the basis would be 33,600.
            verifyLessThan(testCase, numel(gratings), 33600, sprintf( ...
                ['%d visual_grating documents. The Hartley basis is shared ' ...
                 'by all ten generator presentations and must be minted ' ...
                 'ONCE; a per-presentation mint gives ten copies.'], ...
                numel(gratings)));

            % THE PHASE IS THE FIELD WITHOUT WHICH THE SET COLLAPSES: with it
            % the 3360 basis functions give 3360 distinct values, without it
            % 1680. So both signs must be present among the minted documents.
            phases = [];
            for k = 1:numel(gratings)
                v = gratings{k}.visual_grating.value;
                if isfield(v, 'phase') && ~isempty(v.phase)
                    phases(end+1) = double(v.phase); %#ok<AGROW>
                end
            end
            verifyNotEmpty(testCase, phases, ...
                'no visual_grating carries a phase; the signed pair collapses');
            verifyGreaterThanOrEqual(testCase, numel(unique(phases)), 2, ...
                ['only one distinct phase across the basis -- the s = -1 ' ...
                 'half of every (kx,ky) pair has deduped away']);

            % and the pixel-domain frequency did NOT go into the
            % cycles-per-degree field
            withGeom = 0;
            for k = 1:numel(gratings)
                v = gratings{k}.visual_grating.value;
                if isfield(v, 'source_geometry') && isstruct(v.source_geometry) ...
                        && isfield(v.source_geometry, 'unit') ...
                        && strcmp(char(v.source_geometry.unit), 'cycles/pixel')
                    withGeom = withGeom + 1;
                end
            end
            verifyGreaterThan(testCase, withGeom, 0, ...
                ['no visual_grating carries source_geometry in ' ...
                 'cycles/pixel; the Hartley spatial frequency has nowhere ' ...
                 'correct to live']);
        end

        function testTheFrameTimesSurviveAsAnIrregularTimeAxis(testCase)
            % frameTimes is the ONLY surviving stimulus timing on this
            % corpus. The writer moved `presentation_time` into
            % presentation_time.bin -- declared by 11 of 11 presentations and
            % present in 0 of them -- and a struct-level batch pass does not
            % open attached binaries.
            migrated = destinationBodies(testCase.Result.destination);
            seqs = findAllByClass(migrated, 'timed_sequence_manipulation');
            withAxis = 0;
            for k = 1:numel(seqs)
                st = seqs{k}.subject_statement;
                if isfield(st, 'axes') && ~isempty(st.axes) ...
                        && isfield(st.axes(1), 'n') && st.axes(1).n > 1
                    withAxis = withAxis + 1;
                end
            end
            verifyGreaterThanOrEqual(testCase, withAxis, 10, sprintf( ...
                ['%d of the migrated sequences carry a time axis. The ten ' ...
                 'Hartley presentations each have a frameTimes of 3360, so ' ...
                 'fewer than ten means the timing was dropped -- and it is ' ...
                 'not recoverable from anywhere else in this corpus.'], ...
                withAxis));
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
