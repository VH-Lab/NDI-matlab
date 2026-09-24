classdef TestMigrateLocalEtaPRED < matlab.unittest.TestCase
%TESTMIGRATELOCALETAPRED The PRED corpus through the WHOLE V_eta pipeline.
%
%   THE GAP THIS CLOSES, STATED AS A MEASUREMENT RATHER THAN A CLAIM:
%
%       $ cd NDI-matlab && grep -rn "\bPRED\b" --include=*.m --include=*.yml \
%             src/ tests/ .github/ | grep -v PREDATED
%       (no output)
%
%   Zero occurrences. NDI's second pass had never seen a PRED document. The
%   DID side gates PRED hard (0 quarantine, and since 2026-08-13 0 orphans),
%   but that gate runs `did2.convert.v1_to_v2` plus the nine DID-side batch
%   post-passes and STOPS. Everything in `ndi.migrate.local` after that --
%   epochAnchorFold, the assemblers, the second-pass reports -- was covered
%   only by `TestMigrateLocalEta`, which says so in its own words: it "closes
%   on 4- and 5-document fixtures, not on a corpus."
%
%   THE EPOCH CHAIN IS WHY THAT MATTERS TODAY, and it is three links long:
%
%       migrators_j/pyraview      emits an `epoch_bounded_reference` HANDLE
%                                 (epochid + epoch_clock + the extent), and
%                                 points the observation at it through
%                                 `time_reference_2`
%       did2.convert.epochMint    mints one `epoch` per (base.session_id,
%                                 epoch-id string) pair
%       ndi.migrate.internal.epochAnchorFold
%                                 folds the handle into a `relative_reference`
%                                 anchored to that `epoch`, carrying the
%                                 extent, base.id PRESERVED
%
%   The first two are gated against real PRED documents. The third was not.
%   Two thirds of a chain proven on the corpus it was built for is the shape
%   of gap this project has paid for before.
%
%   PRED IS THE RIGHT CORPUS FOR THIS AND IT IS NOT AN ARBITRARY PICK. Read
%   from the zip directly, 2026-08-13:
%
%       DENOMINATOR: 14 document(s), 0 skipped, 0 unparseable,
%                    10 distinct class names, 14 distinct base.id,
%                    1 distinct base.session_id
%         daqmetadatareader 1   daqreader_ndr 2   daqsystem 2   element 2
%         filenavigator 2       pyraview 1        session 1     subject 1
%         syncgraph 1           syncrule 1
%       edges examined 13, empty 4, DANGLING 0
%
%   It is 14 documents, so the whole second pass runs in seconds; it carries
%   exactly one `pyraview` with a populated `epochid`
%   (`EST_VISUAL_PREDROGA`), a `dev_local_time` clocktype and a real
%   `t0_t1` of [0, 28.12495], which is the only input the epoch chain needs;
%   and it carries a `session` document, without which epochMint refuses and
%   the chain cannot start.
%
%   AND IT IS THE FIRST CORPUS TO EMIT A TIME-REFERENCE FAMILY OF SIZE > 1.
%   The pyraview observation carries BOTH `time_reference_1` (the session
%   anchor) and `time_reference_2` (the epoch reference). `referent_unique_by`
%   requires `value.clock` UNIQUE across a `time_reference_#` family, and the
%   digest has been printing that rule's zero with the words "NOTHING IN
%   REACH CARRIES TWO MEMBERS OF A GOVERNED FAMILY. The rule could not fire;
%   the zero is 'untested', not 'clean'." This test is where it first fires.
%
%   WHAT IS DELIBERATELY NOT ASSERTED HERE. No per-class document count is
%   pinned. PRED's migrated class mix moves whenever a fold changes, and a
%   test that pins it turns every intended change into a red gate somewhere
%   unrelated -- the failure mode CLAUDE.md names for the corpus gate ("per-
%   class counts shift as classes dissolve, total-doc counts are the
%   invariant"). What is pinned is the INVARIANTS: nothing quarantines,
%   nothing dangles, the chain resolves, and no retired class reaches the
%   destination.
%
%   Requires, exactly as TestMigrateLocalEta does:
%     - mksqlite on the path,
%     - NDI_TEST_ETA truthy, and
%     - DID_SCHEMA_PATH pointing at an assembled V_eta schema set.
%   It additionally needs NETWORK ACCESS to fetch the corpus zip once, and
%   skips honestly rather than failing when the fetch is impossible -- a
%   corpus this test could not download is not a corpus that failed.
%
%   STATUS: NOT VERIFIED BY EXECUTION in the authoring environment (no
%   MATLAB). CI is the first execution of every line here.

    properties
        SessionRoot
        PredDir
    end

    methods (TestClassSetup)
        function gate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~etaEnabled()
                assumeFail(testCase, 'NDI_TEST_ETA not truthy; skipping V_eta e2e.');
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; need a V_eta schema set.');
            end
            % FETCHED ONCE FOR THE CLASS, and a failure to fetch is a SKIP
            % rather than a failure: "the corpus could not be downloaded" and
            % "the corpus did not migrate" are different findings and must not
            % render alike.
            try
                testCase.PredDir = ensurePREDCorpus();
            catch fetchErr
                assumeFail(testCase, sprintf( ...
                    'could not fetch the PRED corpus (%s); skipping.', ...
                    fetchErr.message));
            end
        end
    end

    methods (TestMethodSetup)
        function makeFreshSession(testCase)
            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));
        end
    end

    methods (TestMethodTeardown)
        function cleanupSession(testCase)
            try
                if isfolder(testCase.SessionRoot)
                    rmdir(testCase.SessionRoot, 's');
                end
            catch
            end
        end
    end

    methods (Test)

        function testTheWholeCorpusMigratesWithNothingQuarantinedOrDangling(testCase)
            % THE HEADLINE GATE, AND ITS DENOMINATOR COMES FIRST. A pass over
            % zero documents quarantines zero documents; that reading and a
            % clean migration print the same digit, which is the silentLoss
            % defect this repository has paid for over two days.
            [result, bodies] = runPredMigrate(testCase);
            verifyEqual(testCase, numel(bodies), 14, ...
                ['the PRED corpus did not read as 14 documents; every ' ...
                 'assertion below would be about a different corpus']);
            verifyGreaterThan(testCase, result.summary.total, 0, ...
                'the migration saw no documents at all');

            verifyEmpty(testCase, result.quarantine, quarantineDiag(result));
            % ...and nothing left deferred for a layer that has already run.
            for k = 1:numel(result.quarantine)
                verifyEmpty(testCase, regexp(result.quarantine(k).reason, ...
                    'needsSessionContext|NDI layer', 'once'), ...
                    sprintf('a document was left deferred: %s', ...
                        result.quarantine(k).reason));
            end

            % THE GRAPH CLOSES. This is the half of the corpus gate that
            % testCorpusPRED did not run until 2026-08-13, and the DID side
            % cannot check it past its own passes anyway: epochAnchorFold
            % REPLACES a document's class, so an id it failed to preserve
            % dangles only here.
            verifyEqual(testCase, result.references.orphan_count, 0, ...
                ['the migrated graph does not close. ' resultDiag(result)]);
            verifyGreaterThan(testCase, result.references.edges_examined, 0, ...
                ['the reference sweep examined 0 edges, so its 0 orphans is ' ...
                 'a statement about the sweep and not about the corpus']);
        end

        function testEveryDocumentThatDidNotConvertDidSoDeliberately(testCase)
            % THE GAP THE HEADLINE GATE LEAVES OPEN. `0 quarantined` +
            % `0 orphans` says the migration did not BREAK anything; it says
            % nothing about whether every document reached its DECIDED shape.
            % A migrator that hands its input straight back is counted in
            % `migrated_count` -- nothing errored, nothing dangled, and the
            % result is a valid v1-class document that did2.validate.silentLoss
            % cannot see either. v1_to_v2 counts it per class at :259; this
            % test supplies the EXPECTATION that separates a deliberate
            % deferral from an accidental fall-through, which its own comment
            % says is the only thing that can.
            %
            % PRED IS THE CLEAN END OF THE SCALE and that is why it belongs
            % here as well as on 20211116: 12 of its 14 documents convert, so
            % this corpus can hold the assertion nearly tight, and any drift
            % shows up as a third class rather than as a bigger number.
            % Checked against the real documents off the corpus zip before
            % the rows were written -- reading the guard is not enough,
            % because every one of these guards is conditional:
            %
            %   DENOMINATOR: 10 distinct class(es) over 14 document(s);
            %                7 have a `bodies = {preBody}` branch at all
            %     daqsystem          2/2 carry `ndi_daqsystem_class`      -> converts
            %     filenavigator      2/2 carry class AND epochprobemap    -> converts
            %     daqmetadatareader  1/1 carries class AND file parameter -> converts
            %     daqreader_ndr      2/2 carry class AND `ndr_reader_string`
            %                            ('intan')                        -> converts
            %   element, session, subject and pyraview have no passthrough
            %   branch, so they cannot take one.
            [result, bodies] = runPredMigrate(testCase);
            s = result.summary;

            fprintf(['\n  PASS-1 CONVERSION CENSUS (PRED)\n' ...
                     '    DENOMINATOR: %d document(s) read, %d migrated, ' ...
                     '%d quarantined\n' ...
                     '    unconverted (migrator returned its input): %d\n' ...
                     '    fragments (emitted, but hollow):           %d\n'], ...
                s.total, s.migrated_count, s.quarantine_count, ...
                s.unconverted_count, s.fragment_count);
            ndi.unittest.migrate.printClassTable(s.unconverted_by_class, '    unconverted');
            ndi.unittest.migrate.printClassTable(s.fragment_by_class,    '    fragment');

            verifyEqual(testCase, numel(bodies), 14, ...
                'the pass did not see 14 documents; every figure here is about a different corpus');

            % A FRAGMENT IS NEVER DELIBERATE: unlike a passthrough it is a
            % document the migrator DID emit and that carries nothing.
            verifyEqual(testCase, s.fragment_count, 0, sprintf( ...
                ['%d document(s) migrated to a FRAGMENT. A passthrough is a ' ...
                 'deferral; a fragment is silent loss.'], s.fragment_count));

            declared = { ...
                'syncgraph', ...
                    ['THE SESSION GATE, and it fires on every document IN PASS 1: ' ...
                     '+migrators_j/syncgraph.m says of `jSessionDocId` that it "answers '''' ' ...
                     'by construction in pass 1 -- the same shape as jEpochDocId". The fold ' ...
                     'has moved into the batch phase (#57): did2.convert.resolveClockAlignment ' ...
                     'supplies the session-document id and folds it to `clock_alignment_policy`, ' ...
                     'so syncgraph is a pass-1 passthrough by design and is ABSENT from the ' ...
                     'final-output survivor census (which for PRED is now subject + session ' ...
                     'only -- both persist)']; ...
                'subject', ...
                    ['PERSIST, NOT A DEFERRAL. A v1 `subject` IS the V_eta `subject`, and ' ...
                     '+migrators_j/subject.m only fills `local_identifier` when empty; this ' ...
                     'subject already carries one, so the migrator returns its input and the ' ...
                     'census counts "unconverted". The census is literal -- "returned its ' ...
                     'input" spans a deferral and a correct identity migration -- and this ' ...
                     'row''s appearance is proof the handle was already set']};

            ndi.unittest.migrate.verifyDeferralsAreDeclared(testCase, ...
                s.unconverted_by_class, declared);
        end

        function testNoV1DocumentSurvivesUnfoldedInTheFinalOutput(testCase)
            % THE BAR-2 INSTRUMENT -- see TestMigrateLocalEta20211116 for the
            % full rationale. REPORT-ONLY on this first landing: it prints which
            % v1 source class names still label a destination document (a class
            % that did not fold), and asserts only its own denominators. The
            % assertion arm lands once the survivor set is read and the folds
            % that close it are built.
            [result, bodies] = runPredMigrate(testCase);
            dst = destinationBodies(result.destination);
            survivors = ndi.unittest.migrate.finalV1SurvivorCensus( ...
                reshape(bodies, 1, []), reshape(dst, 1, []));

            fprintf(['\n  BAR-2 FINAL-OUTPUT V1 SURVIVOR CENSUS (PRED)\n' ...
                     '    DENOMINATOR: %d source document(s), %d destination ' ...
                     'document(s)\n' ...
                     '    v1 source class names still labelling a destination ' ...
                     'document: %d\n'], ...
                numel(bodies), numel(dst), numel(survivors));
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
            verifyEqual(testCase, numel(bodies), 14, ...
                'the source census did not read 14 documents');
            verifyGreaterThan(testCase, numel(dst), 0, ...
                'the destination census read zero documents');
        end

        function testTheEpochChainResolvesOnRealDocuments(testCase)
            % The three links, each asserted through the pass's OWN counters
            % before any class-name check -- so "the fold did not run" and
            % "the fold ran and refused" are different failures rather than
            % one shared silence.
            result = runPredMigrate(testCase);

            mint = result.secondPass.epochMint;
            verifyNotEmpty(testCase, mint, 'epochMint did not run at all');
            verifyEqual(testCase, mint.session_documents_seen, 1, ...
                ['PRED carries exactly one `session` document and epochMint ' ...
                 'did not see it, so it had nothing to anchor an `epoch` to. ' ...
                 resultDiag(result)]);
            verifyEqual(testCase, mint.skipped_no_session_document, 0, ...
                resultDiag(result));

            fold = result.secondPass.epochAnchorFold;
            verifyNotEmpty(testCase, fold, ...
                ['the epoch anchor fold did not run; ndi.migrate.local warns ' ...
                 'and continues when it throws, so its absence is silent. ' ...
                 resultDiag(result)]);
            % PRED holds ONE pyraview with a populated epochid, so the pass-1
            % handle count is 1. Asserted rather than assumed: if pyraview
            % stops emitting the handle this reads 0 and the rest of this test
            % would pass vacuously.
            verifyEqual(testCase, fold.anchors_seen, 1, ...
                ['no pass-1 epoch anchor reached the fold; pyraview did not ' ...
                 'emit its epoch_bounded_reference handle. ' resultDiag(result)]);
            verifyEqual(testCase, fold.refused_total, 0, resultDiag(result));
            verifyEqual(testCase, fold.anchors_refolded, 1, resultDiag(result));
            verifyEqual(testCase, fold.refold_quarantined, 0, resultDiag(result));
            % the accounting invariant: no third bucket an anchor can vanish into
            verifyEqual(testCase, fold.anchors_seen, ...
                fold.anchors_planned + fold.refused_total, resultDiag(result));

            % THE RETIRED CLASS IS GONE. `epoch_bounded_reference` is a pass-1
            % TRANSPORT HANDLE, not a destination -- it is `in_progress` in
            % V_eta_final_class_set.md and not in the persist set. One reaching
            % the destination database means the fold silently did nothing.
            verifyFalse(testCase, ...
                isfield(result.summary.by_class, 'epoch_bounded_reference'), ...
                ['a class the signed decision RETIRES was written to the ' ...
                 'destination database. ' resultDiag(result)]);
            verifyTrue(testCase, isfield(result.summary.by_class, 'epoch'), ...
                resultDiag(result));
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'relative_reference'), ...
                resultDiag(result));
        end

        function testTheObservationStillNamesItsEpochAfterTheFold(testCase)
            % THE ORPHAN GATE, AT THE ONE EDGE THAT ONLY THIS PASS CAN BREAK.
            % pyraview writes `time_reference_2` in pass 1, pointing at the
            % handle's id. epochAnchorFold then REPLACES that document's class.
            % If it mints a fresh id instead of preserving it, the edge dangles
            % -- the 11,448-orphan dissolution failure, one class over.
            result = runPredMigrate(testCase);

            docs = destinationBodies(result.destination);
            obs = pyraviewObservation(testCase, docs);
            verifyNotEmpty(testCase, obs, ...
                ['pyraview did not produce a voltage_observation. ' ...
                 resultDiag(result)]);
            epochRefId = depValue(obs, 'time_reference_2');
            verifyNotEmpty(testCase, epochRefId, ...
                ['the observation carries no `time_reference_2`, so it is no ' ...
                 'longer attached to its epoch. ' resultDiag(result)]);

            ref = findById(docs, epochRefId);
            verifyNotEmpty(testCase, ref, ...
                ['`time_reference_2` names a document that is not in the ' ...
                 'destination -- the fold moved the anchor id. ' ...
                 resultDiag(result)]);
            verifyEqual(testCase, ref.document_class.class_name, ...
                'relative_reference', ...
                ['the epoch anchor did not become a relative_reference. ' ...
                 resultDiag(result)]);

            % ...and it points at the epoch epochMint actually minted.
            epochDoc = findByClass(docs, 'epoch');
            verifyNotEmpty(testCase, epochDoc, resultDiag(result));
            verifyEqual(testCase, depValue(ref, 'relative_to'), ...
                epochDoc.base.id, ...
                ['the folded reference does not name the minted epoch. ' ...
                 resultDiag(result)]);
        end

        function testTheMigratedSessionOpensAndReadsBackThroughNDI(testCase)
        %TESTTHEMIGRATEDSESSIONOPENSANDREADSBACKTHROUGHNDI The READ path.
        %   Everything else in this file proves the documents MIGRATE and
        %   VALIDATE. None of it proves MATLAB can still USE them: no job opens
        %   a migrated database through NDI's object API, so "the documents are
        %   correct" and "NDI can read them" have been two claims with only the
        %   first one tested. Asked by the team 2026-08-13, with this exact
        %   case: can `ndi.session.dir` still turn a migrated session into an
        %   object?
        %
        %   NOTHING IS COPIED OVER A HARD-CODED NAME ANY MORE, AND THAT CHANGE
        %   IS THE POINT. The first version of this test copied
        %   `V_eta.sqlite` over `did-sqlite.sqlite` in a throwaway session,
        %   because NDI could not open a migrated database at all: the
        %   migrator writes `<TargetVersion>.sqlite` (`local.m:195`) while
        %   `didsqlite.m:24` hard-codes `did-sqlite.sqlite`. That copy hid
        %   TWO separate failures behind one workaround -- where the file
        %   lives, and what can read it -- and the second was the real one:
        %   the two backends are DIFFERENT FORMATS. `did.implementations.
        %   sqlitedb` is branch-versioned (`branches`, and the open fails
        %   with '"branches" table not found'); `did2.database.sqlitedb` has
        %   no notion of a branch anywhere. Copying the file across only
        %   moved a did2 database under a name a legacy reader would open.
        %
        %   Both halves are now built, so the session is opened WHERE THE
        %   MIGRATOR LEFT IT:
        %       ndi.database.implementations.database.did2sqlite   -- reads it
        %       ndi.database.fun.databasehierarchyinit             -- finds it
        %   If either regresses this test fails at `ndi.session.dir`, which is
        %   exactly the failure a user would hit.
        %
        %   SCOPE IS PRED, DELIBERATELY. PRED holds 10 v1 classes and none of
        %   the analysis tier, so this covers session/subject/element/daq and
        %   says nothing about `stimulus_tuningcurve` (64 by-path reads) or
        %   `openminds` (59). Those need a stimulus corpus; claiming otherwise
        %   from a green run here would be the "corpora are a sample" rule
        %   broken in the read path.
            result = runPredMigrate(testCase);

            % The migrated file is taken from the MIGRATOR'S OWN ANSWER rather
            % than reconstructed from a filename this test guesses -- if
            % `<TargetVersion>.sqlite` ever changes, this follows it instead of
            % failing on a stale assumption.
            assertTrue(testCase, isfile(result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                result.destination));

            % THE FIXTURE IS MISSING ONE FILE A REAL SESSION ALWAYS HAS, and
            % writing it here is a fixture repair, not a shortcut around the
            % thing under test.
            %
            % `ndi.session.dir` decides WHICH session it is before it opens
            % anything: it reads `.ndi/unique_reference.txt`, and
            % `database_search` then ANDs `base.session_id == that id` into
            % every query. This fixture builds a session directory out of
            % corpus bodies and never writes that file, so the id would be a
            % freshly minted random one, the session query would match
            % nothing, and dir.m would fall through to `reference.txt` and
            % error -- a fixture artefact with nothing to say about V_eta.
            % Every real session directory has the file, because dir.m
            % writes it at the end of every open.
            %
            % ONLY `unique_reference.txt` IS WRITTEN, DELIBERATELY.
            % `reference.txt` is the FALLBACK dir.m uses when the database
            % cannot answer; writing it would let this test pass without the
            % database being read at all, which is the one thing it exists to
            % prove. The id comes from the MIGRATED session document.
            migrated = destinationBodies(result.destination);
            sessionDoc = findByClass(migrated, 'session');
            assertNotEmpty(testCase, sessionDoc, ...
                ['no `session` document in the migrated database -- ' ...
                 'ndi.session.dir has nothing to identify the session by']);
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), ...
                sessionDoc.base.session_id);

            % THE HEADLINE. If this errors, NDI cannot open a migrated session
            % and every assertion below is moot.
            s = ndi.session.dir(testCase.SessionRoot);
            assertTrue(testCase, isa(s, 'ndi.session.dir'), ...
                'ndi.session.dir did not return a session object');

            % SELECTION IS ASSERTED, NOT ASSUMED. The session directory holds
            % BOTH databases -- the original the migration read and the
            % V_eta one it wrote -- so "it opened" does not by itself say
            % WHICH opened. Without this a hierarchy that silently fell back
            % to the legacy file would pass every assertion below that does
            % not turn on a rename.
            %
            % `ndi.session`'s `database` property is not publicly readable,
            % so the selection is re-run through the same function
            % `ndi.session.dir` calls rather than reached for through the
            % object. That tests the mechanism, which is the thing that can
            % regress.
            selected = ndi.database.fun.opendatabase( ...
                fullfile(testCase.SessionRoot, '.ndi'), s.id());
            assertTrue(testCase, isa(selected, ...
                'ndi.database.implementations.database.did2sqlite'), sprintf( ...
                ['ndi.database.fun.opendatabase chose a "%s", not a ' ...
                 'did2sqlite -- the migrated database was written and ' ...
                 'something else was opened'], class(selected)));

            % The session's own identity, read back off a MIGRATED document --
            % `session.reference` is `local_identifier` in V_eta, and this is
            % the read the team named.
            assertNotEmpty(testCase, s.reference, ...
                ['the session opened but carries no reference -- ' ...
                 '+ndi/+session/dir.m reads session.reference / ' ...
                 'local_identifier by path, so an empty value here means the ' ...
                 'both-vintage read stopped working']);
            assertNotEmpty(testCase, s.id(), 'the session has no identifier');

            % Documents come back through the ordinary query API, not by
            % reading the file: this is the path a user actually takes.
            subs = s.database_search(ndi.query('','isa','subject'));
            assertNotEmpty(testCase, subs, ...
                'no subject document came back from a migrated database');

            % PROVE THESE ARE V_eta DOCUMENTS AND NOT v1 ONES. Without this the
            % test would pass just as well against the unmigrated database --
            % it would be reading did-sqlite.sqlite either way, and the copy
            % above would be the only thing that made it meaningful.
            sub = subs{1}.document_properties;
            assertTrue(testCase, isfield(sub, 'subject') ...
                && isfield(sub.subject, 'local_identifier'), ...
                ['the subject read back has no subject.local_identifier -- ' ...
                 'either the V_eta database was not the one opened, or the ' ...
                 'signed rename did not survive the round trip']);
            assertTrue(testCase, isfield(sub.base, 'creation_timestamp'), ...
                ['base.creation_timestamp is absent on a document read back ' ...
                 'through NDI -- V_eta renamed base.datestamp, and 3 NDI ' ...
                 'read sites still name the old spelling']);

            % ---- DOCUMENTS COME BACK; DO OBJECTS? --------------------
            % Everything above proves the DOCUMENTS are readable. None of
            % it proves NDI can turn them into the objects a user actually
            % works with, and those are two different claims: every object
            % loader finds its documents by v1 class name, and `isa` cannot
            % bridge a rename (acquisition_system's chain is [entity],
            % clock_alignment_policy's is [base]). Before ndi.vintage,
            % each of these returned empty with no error.

            % PRED carries 2 `daqsystem` documents. `daqsystem_load` has to
            % find them as `acquisition_system`, resolve each one's MATLAB
            % class through its `software_id` edge, and follow three
            % renamed edges to the reader, the file navigator and the
            % metadata reader -- so one number here exercises the whole
            % daq chain.
            % No name filter: the bare call takes the `isa` + session
            % branch only, so a failure here is about finding the class and
            % not about how a name pattern was written.
            devs = s.daqsystem_load();
            if ~iscell(devs); devs = {devs}; end
            assertEqual(testCase, numel(devs), 2, sprintf( ...
                ['daqsystem_load returned %d daq system(s); PRED holds 2. ' ...
                 'Zero is the pre-ndi.vintage symptom and reads exactly ' ...
                 'like a session with no rigs.'], numel(devs)));
            for k = 1:numel(devs)
                assertTrue(testCase, isa(devs{k}, 'ndi.daq.system'), sprintf( ...
                    'daqsystem_load returned a "%s"', class(devs{k})));
                assertNotEmpty(testCase, devs{k}.name, ...
                    ['the daq system has no name -- base.name is the join ' ...
                     'key probe->device attribution matches on']);
                assertTrue(testCase, isa(devs{k}.filenavigator, 'ndi.file.navigator'), ...
                    'the epoch_file_pattern edge did not resolve to a navigator');
                assertTrue(testCase, isa(devs{k}.daqreader, 'ndi.daq.reader'), ...
                    'the reader_id edge did not resolve to a daq reader');
            end

            % PRED carries 1 syncgraph and 1 syncrule. A syncgraph that was
            % NOT found comes back freshly constructed with ZERO rules and
            % no error, so the rule count -- not the object's existence --
            % is what distinguishes "loaded" from "silently replaced".
            assertTrue(testCase, isa(s.syncgraph, 'ndi.time.syncgraph'), ...
                'the session has no syncgraph object at all');
            assertEqual(testCase, numel(s.syncgraph.rules), 1, sprintf( ...
                ['the syncgraph carries %d rule(s); PRED holds 1. Zero ' ...
                 'means ndi.session.dir did not find the migrated ' ...
                 'clock_alignment_policy and built an empty one instead -- ' ...
                 'a session that opens fine having lost its ' ...
                 'synchronisation.'], numel(s.syncgraph.rules)));
            assertTrue(testCase, isa(s.syncgraph.rules{1}, 'ndi.time.syncrule'), ...
                'the reconstructed rule is not an ndi.time.syncrule');

            % ---- THE ELEMENTS, WHICH IN PRED ARE PROBES --------------
            % Read from the corpus zip: PRED's 2 element documents are
            % `ndi.probe.timeseries.mfdaq` (name electrode16, type n-trode)
            % and `ndi.probe.timeseries.stimulator` (name rayostim, type
            % stimulator). Both are `direct` with an empty
            % underlying_element_id, so they are hardware attached to the
            % one animal, not derived signals.
            %
            % After migration they are `subject` documents -- as is the
            % animal -- so this is the case `isa` cannot decide. The lookup
            % goes through the inbound `ndi element class` assertion.
            els = s.getelements();
            assertEqual(testCase, numel(els), 2, sprintf( ...
                ['getelements returned %d; PRED holds 2 elements. Zero is ' ...
                 'the pre-ndi.vintage symptom; THREE would mean the ' ...
                 'lookup reached `isa subject` and swept in the animal.'], ...
                numel(els)));

            names = sort(cellfun(@(x) string(x.name), els(:)'));
            assertEqual(testCase, names, ["electrode16", "rayostim"], ...
                'the two elements are not the two PRED probes');

            % The MATLAB class is recovered from the assertion, so this is
            % what proves the object-class hop worked rather than some
            % default being constructed.
            classes = sort(cellfun(@(x) string(class(x)), els(:)'));
            assertEqual(testCase, classes, ...
                ["ndi.probe.timeseries.mfdaq", "ndi.probe.timeseries.stimulator"], ...
                'the elements did not rebuild as their recorded probe classes');
        end

        function testTheTimeReferenceFamilyIsTheFirstOfSizeTwoAndIsLegal(testCase)
            % `referent_unique_by` declares a `time_reference_#` family unique
            % by `value.clock`, and until PRED nothing in reach carried two
            % members -- the digest prints that zero as "untested, not clean".
            % This is where the rule first has something to say.
            %
            % IT IS LEGAL BY CONSTRUCTION, and the point of asserting it is
            % that the construction could change without anyone noticing: the
            % session anchor folds to a `relative_reference` whose value is
            % `struct('relation', term)` with NO clock, while the epoch anchor
            % folds to one carrying `dev_local_time`. Two members, two distinct
            % keys. If either fold ever starts writing the other's clock, this
            % is the test that says so.
            result = runPredMigrate(testCase);
            docs = destinationBodies(result.destination);
            obs = pyraviewObservation(testCase, docs);
            verifyNotEmpty(testCase, obs, resultDiag(result));

            ids = {depValue(obs, 'time_reference_1'), ...
                   depValue(obs, 'time_reference_2')};
            verifyNotEmpty(testCase, ids{1}, ...
                ['the observation lost its session anchor, so this family is ' ...
                 'no longer of size 2 and the rule cannot fire. ' ...
                 resultDiag(result)]);
            verifyNotEmpty(testCase, ids{2}, resultDiag(result));

            clocks = {};
            for k = 1:numel(ids)
                doc = findById(docs, ids{k});
                verifyNotEmpty(testCase, doc, sprintf( ...
                    'time_reference_%d names a document not in the destination', k));
                clocks{end+1} = clockOf(doc); %#ok<AGROW>
            end
            verifyNotEqual(testCase, clocks{1}, clocks{2}, sprintf( ...
                ['both members of the time_reference_# family resolve to the ' ...
                 'same clock (%s); `referent_unique_by` declares it UNIQUE. ' ...
                 '%s'], clocks{1}, resultDiag(result)));
        end

    end
end

% ===================== harness ============================================

function [result, bodies] = runPredMigrate(testCase)
%RUNPREDMIGRATE The whole corpus through ndi.migrate.local, as CI runs it.
bodies = readPredBodies(testCase.PredDir);
srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
buildV1Sqlite(srcSqlite, bodies);
result = ndi.migrate.local(testCase.SessionRoot, ...
    'Validate', true, 'TargetVersion', 'V_eta', 'Backup', false);
[~, dstName] = fileparts(result.destination);
verifyEqual(testCase, dstName, 'V_eta');
end

function bodies = readPredBodies(predDir)
%READPREDBODIES Every v1 document in the corpus, as JSON text.
%   `._` sidecars are macOS resource forks the zip carries; skipping them is
%   what did2.validate.sourceCensus's own reader does.
files = dir(fullfile(predDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end
end

function predDir = ensurePREDCorpus()
%ENSUREPREDCORPUS Download (once) and extract PRED.zip.
%   The URL and the cache layout are the same as
%   DID-matlab tests/+did2/+unittest/testCorpusPRED.m:443-456, deliberately:
%   both sides fetching the same corpus from two different places is how the
%   two gates end up run against two different inputs.
corpusURL = 'https://ndi-programming-development.s3.us-east-1.amazonaws.com/PRED.zip';
cacheRoot = fullfile(tempdir(), 'ndi-corpus-PRED');
predDir   = fullfile(cacheRoot, 'PRED');
if isfolder(predDir) && ~isempty(dir(fullfile(predDir, '*.json')))
    return;
end
if ~exist(cacheRoot, 'dir')
    mkdir(cacheRoot);
end
zipPath = fullfile(cacheRoot, 'PRED.zip');
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
end

function buildV1Sqlite(tmpFile, bodies)
%BUILDV1SQLITE A did_v1 sqlite database holding BODIES.
%   Schema copied from TestMigrateLocalEta.m:623-638 rather than shared,
%   because that one is a local subfunction of a classdef; if a third caller
%   appears, promote it rather than copying again.
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
for k = 1:numel(bodies)
    docId = sprintf('id_%04d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
end

function tf = etaEnabled()
raw = lower(strtrim(getenv('NDI_TEST_ETA')));
tf = ismember(raw, {'1', 'true', 'yes', 'y', 'on'});
end

% ===================== readers ============================================
%
% ALL THREE OPEN THE DESTINATION DATABASE. `result.destination` is a PATH, not
% a list of bodies -- the first draft of this file treated it as a cell array
% of structs and every reader would have failed on the first call. Shape and
% API copied from TestMigrateLocalEta.m:595-607, which is the only other
% reader of a V_eta destination in this repository.

function bodies = destinationBodies(dstPath)
%DESTINATIONBODIES Every document in the destination, as structs, read ONCE.
%   Read once and reused, rather than reopening the database per lookup: these
%   tests ask three or four questions of the same 20-odd documents, and a
%   per-question open is how a 14-document corpus test starts taking minutes.
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end

function doc = findByClass(bodies, className)
%FINDBYCLASS The FIRST document of a class. Safe only where the class is
%   unique in the batch -- see findAllByClass and pyraviewObservation.
doc = [];
hits = findAllByClass(bodies, className);
if ~isempty(hits); doc = hits{1}; end
end

function hits = findAllByClass(bodies, className)
hits = {};
for k = 1:numel(bodies)
    d = bodies{k};
    if isstruct(d) && isfield(d, 'document_class') ...
            && strcmp(d.document_class.class_name, className)
        hits{end+1} = d; %#ok<AGROW>
    end
end
end

function obs = pyraviewObservation(testCase, bodies)
%PYRAVIEWOBSERVATION PRED's pyraview observation, told apart from element's.
%   PRED YIELDS **TWO** `voltage_observation` DOCUMENTS and the first draft of
%   this file assumed one. `findByClass` returned whichever the database
%   happened to yield first, and on the first real run that was ELEMENT's --
%   which legitimately carries `time_reference_1` and no `time_reference_2`.
%   The test then reported the epoch link as missing when it was looking at
%   the wrong document. A migration defect and a selector defect printed
%   identically, which is the whole reason this helper exists.
%
%   THE DISCRIMINATOR IS NOT `time_reference_2`. Selecting on the very edge
%   under test would make the assertion vacuous -- it would find whichever
%   document already satisfies it, or none, and never report a real loss.
%   `instrument_id` is used instead, and it is the RECORDED difference between
%   the two emitters (DID-schema status_board.py, family `raw recording
%   observation`):
%
%     element   private/jRecordingObservation.m:211-212
%         subject_id = the SPECIMEN, instrument_id = the electrode
%     pyraview  migrators_j/pyraview.m:225
%         subject_id = element_id (the probe-as-subject), NO instrument_id
%
%   So pyraview's is the one WITHOUT an instrument edge. Both the count and
%   the partition are asserted, so if either emitter changes shape this fails
%   loudly rather than silently picking the other document.
allObs = findAllByClass(bodies, 'voltage_observation');
assertEqual(testCase, numel(allObs), 2, sprintf( ...
    ['PRED should yield exactly 2 voltage_observation documents (element''s ' ...
     'raw recording and pyraview''s pyramid); found %d. The selector below ' ...
     'cannot be trusted until this holds.'], numel(allObs)));
%   THE DISCRIMINATOR CHANGED 2026-08-13, AND THE OLD ONE IS WHY. It was
%   `instrument_id` -- present on element's, absent on pyraview's. The
%   second-pass `recordingAttribution` now gives pyraview's observation the
%   same specimen and the same instrument edge, which is the entire point of
%   that pass and which makes the old discriminator select NOTHING. A test
%   whose selector is the property under repair cannot survive the repair.
%
%   `base.name` is used instead, and it is a WRITER-SIDE constant on both
%   sides rather than anything this pass touches:
%       element   private/jRecordingObservation.m:215  'migrated_recording_observation'
%       pyraview  migrators_j/pyraview.m               'migrated_signal'
byName = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(allObs)
    nm = '';
    st = allObs{k};
    if isfield(st, 'base') && isstruct(st.base) && isfield(st.base, 'name')
        nm = char(st.base.name);
    end
    if ~isKey(byName, nm)
        byName(nm) = {};
    end
    acc = byName(nm);
    acc{end+1} = allObs{k}; %#ok<AGROW>
    byName(nm) = acc;
end
assertTrue(testCase, isKey(byName, 'migrated_signal'), ...
    ['no voltage_observation carries base.name `migrated_signal` -- pyraview ' ...
     'stopped naming its observation, and the selector needs a new discriminator']);
assertTrue(testCase, isKey(byName, 'migrated_recording_observation'), ...
    ['no voltage_observation carries base.name `migrated_recording_observation` ' ...
     '-- element''s raw-recording observation is missing entirely']);
pyr = byName('migrated_signal');
assertEqual(testCase, numel(pyr), 1, ...
    'more than one pyraview observation; the selector is ambiguous');
obs = pyr{1};

% THE SIGNED ATTRIBUTION, asserted on pyraview's document specifically. Before
% recordingAttribution this observation named the PROBE as its subject and no
% instrument at all, so "every recording from this specimen" missed it.
elemObs = byName('migrated_recording_observation');
specimenId = depValue(elemObs{1}, 'subject_id');
probeId    = depValue(elemObs{1}, 'instrument_id');
assertNotEmpty(testCase, specimenId, ...
    'element''s observation names no specimen; the donor map would be empty');
assertEqual(testCase, depValue(obs, 'subject_id'), specimenId, ...
    ['pyraview''s observation is not attributed to the SPECIMEN -- ' ...
     'recordingAttribution did not run, or refused it']);
assertEqual(testCase, depValue(obs, 'instrument_id'), probeId, ...
    'pyraview''s observation does not name the probe as its instrument (T7)');
end

function doc = findById(bodies, docId)
doc = [];
if isempty(docId); return; end
for k = 1:numel(bodies)
    d = bodies{k};
    if isstruct(d) && isfield(d, 'base') && isfield(d.base, 'id') ...
            && strcmp(d.base.id, docId)
        doc = d;
        return;
    end
end
end

function v = depValue(body, name)
%DEPVALUE Both spellings, as TestMigrateLocalEta.m:609-621 reads them.
v = '';
if isempty(body) || ~isfield(body, 'depends_on') || ~isstruct(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value'); v = d.value;
        elseif isfield(d, 'document_id'); v = d.document_id; end
        return;
    end
end
end

function c = clockOf(doc)
%CLOCKOF The family's discriminator, or a NAMED absence.
%   An absent clock is a distinct key rather than an error: the session anchor
%   legitimately has none. It is returned as a sentinel string so the
%   uniqueness assertion compares two values rather than special-casing one.
c = '<no clock>';
if isempty(doc); return; end
for blk = {'relative_reference', 'epoch_bounded_reference', 'absolute_reference'}
    if ~isfield(doc, blk{1}); continue; end
    b = doc.(blk{1});
    if isstruct(b) && isfield(b, 'value') && isstruct(b.value) ...
            && isfield(b.value, 'clock')
        c = clockString(b.value.clock);
        return;
    end
end
end

function s = clockString(clockCell)
%CLOCKSTRING The bound term's node, however the cell is shaped.
s = '<no clock>';
if ischar(clockCell) || isstring(clockCell)
    s = char(clockCell);
elseif isstruct(clockCell)
    for f = {'node', 'name', 'value'}
        if isfield(clockCell, f{1}) && ~isempty(clockCell.(f{1}))
            s = char(clockCell.(f{1}));
            return;
        end
    end
end
end

% ===================== diagnostics ========================================

function s = quarantineDiag(result)
if isempty(result.quarantine)
    s = '';
    return;
end
lines = cell(1, numel(result.quarantine));
for k = 1:numel(result.quarantine)
    lines{k} = sprintf('  [%s] %s', ...
        result.quarantine(k).class_name, result.quarantine(k).reason);
end
s = sprintf('PRED quarantined %d/%d:\n%s', numel(result.quarantine), ...
    result.summary.total, strjoin(lines, sprintf('\n')));
end

function s = resultDiag(result)
%RESULTDIAG What the migration actually produced, so a missing-document
%   failure names the migrated classes instead of reporting `[]`.
byClass = '(none)';
if isfield(result, 'summary') && isfield(result.summary, 'by_class') ...
        && isstruct(result.summary.by_class)
    fns = fieldnames(result.summary.by_class);
    if ~isempty(fns); byClass = strjoin(fns(:)', ', '); end
end
s = sprintf('[migrated classes: %s] %s', byClass, quarantineDiag(result));
end
