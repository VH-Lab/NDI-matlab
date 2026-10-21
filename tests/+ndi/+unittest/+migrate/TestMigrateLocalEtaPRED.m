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

            % NO DECLARED DEFERRALS ON did-schema #88. The two rows this held
            % (`syncgraph`, the pass-1 session gate; `subject`, the identity
            % migration) both stopped firing when the migrators were ported to
            % #88 (DID-matlab #218): e2e run 39668356516 printed "unconverted:
            % 0" over PRED's 14 documents and "2 of 2 declared deferral(s) no
            % longer fire". The helper still fails on any NEW passthrough.
            declared = cell(0, 2);

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
            % ON did-schema #88 THE PYRAVIEW ANCHOR IS NOT A HANDLE ANY MORE.
            % Pre-#88 pyraview emitted an `epoch_bounded_reference` (the epoch
            % named by its string) that NDI's epochAnchorFold re-pointed. On
            % #88 (DID-matlab +migrators_j/pyraview.m, "the time anchor") a
            % pyraview naming an epoch DEFERS in pass 1, and
            % did2.convert.epochMint mints the epoch entity and folds it, with
            % a `relative_time_reference` onto that entity. So the chain is
            % asserted through epochMint's own pyraview counters, and NDI's
            % fold -- which on #88 re-points only the stimulus-bath anchors --
            % must see nothing here (PRED has no bath).
            verifyEqual(testCase, mint.pyraview_deferred_seen, 1, ...
                ['PRED holds ONE pyraview with a populated epochid and ' ...
                 'epochMint did not see it deferred. ' resultDiag(result)]);
            verifyEqual(testCase, mint.pyraview_deferred_resolved, 1, ...
                ['epochMint saw the deferred pyraview and did not fold it. ' ...
                 resultDiag(result)]);
            verifyGreaterThanOrEqual(testCase, mint.epochs_minted, 1, ...
                resultDiag(result));
            verifyEqual(testCase, fold.anchors_seen, 0, ...
                ['NDI''s epoch anchor fold found a pass-1 anchor in a corpus ' ...
                 'with no stimulus bath; on #88 no migrator emits one. ' ...
                 resultDiag(result)]);
            verifyEqual(testCase, fold.refused_total, 0, resultDiag(result));
            verifyEqual(testCase, fold.refold_quarantined, 0, resultDiag(result));
            % the accounting invariant: no third bucket an anchor can vanish into
            verifyEqual(testCase, fold.anchors_seen, ...
                fold.anchors_planned + fold.refused_total, resultDiag(result));

            % NO RETIRED OR PRE-#88 TIME CLASS REACHES THE DATABASE, and the
            % #88 one does. The epoch is an `entity` of type epoch (T1), so it
            % is looked for by type, not by a class of its own.
            for c = {'epoch_bounded_reference', 'relative_reference', 'epoch'}
                verifyFalse(testCase, isfield(result.summary.by_class, c{1}), ...
                    ['`' c{1} '` was written to the destination. ' resultDiag(result)]);
            end
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'relative_time_reference'), ...
                resultDiag(result));
            docs = destinationBodies(result.destination);
            verifyNotEmpty(testCase, findEntity(docs, 'epoch'), ...
                ['no entity of type epoch in the destination. ' resultDiag(result)]);
        end

        function testTheObservationStillNamesItsEpochAfterTheFold(testCase)
            % THE ORPHAN GATE, AT THE ONE EDGE THE EPOCH FOLD CAN BREAK. On
            % did-schema #88 pyraview's observation (an `observation` listing
            % the `voltage` value kind) names its time through
            % `time_reference_id`, a `relative_time_reference` whose
            % `referent_id` is the EPOCH ENTITY epochMint minted. If the fold
            % mints the reference and drops the edge, or points it at nothing,
            % the observation is no longer attached to its epoch.
            [result, bodies] = runPredMigrate(testCase);

            docs = destinationBodies(result.destination);
            obs = pyraviewObservation(testCase, docs, bodies);
            refIds = depValues(obs, 'time_reference_id');
            verifyNotEmpty(testCase, refIds, ...
                ['the observation carries no `time_reference_id`, so it is no ' ...
                 'longer attached to its epoch. ' resultDiag(result)]);
            if isempty(refIds); return; end

            epochDoc = findEntity(docs, 'epoch');
            verifyNotEmpty(testCase, epochDoc, resultDiag(result));
            if isempty(epochDoc); return; end
            refs = cellfun(@(id) findById(docs, id), refIds, 'UniformOutput', false);
            verifyFalse(testCase, any(cellfun(@isempty, refs)), ...
                ['a `time_reference_id` names a document that is not in the ' ...
                 'destination. ' resultDiag(result)]);
            refs = refs(~cellfun(@isempty, refs));
            onEpoch = cellfun(@(r) strcmp(r.document_class.class_name, ...
                'relative_time_reference') && strcmp(depValue(r, 'referent_id'), ...
                epochDoc.base.id), refs);
            verifyEqual(testCase, sum(onEpoch), 1, ...
                ['exactly one of the observation''s time references must be a ' ...
                 'relative_time_reference onto the minted epoch. ' resultDiag(result)]);
        end

        function testPyraviewIsAttributedToTheSpecimen(testCase)
            % TEAM-SIGN-OFF [raw recording observation], 2026-08-10: a raw
            % recording is about the SPECIMEN, with the probe as its
            % instrument (T7). recordingAttribution makes pyraview's
            % observation agree with the element's recording observation
            % (the donor). On did-schema #88 the element emits no recording
            % observation in pass 1 (DID-matlab jRecordingObservation, "SINCE
            % 2026-10-21 IT EMITS NO OBSERVATION"): it is minted per epoch
            % from the epoch's files, which PRED does not carry, so there is
            % no such donor. Decided by Jess Haley, 2026-10-21 [preview
            % attribution without epoch files] (did-schema
            % V_eta_recording_observation_plan.md): the element's kept
            % `observes` relation (probe observes organism) is the donor.
            [result, bodies] = runPredMigrate(testCase);
            docs = destinationBodies(result.destination);
            obs = pyraviewObservation(testCase, docs, bodies);
            organism = findEntity(docs, 'organism');
            assertNotEmpty(testCase, organism, ...
                ['PRED holds one animal and no entity of type organism came ' ...
                 'back. ' resultDiag(result)]);
            ra = result.secondPass.recordingAttribution;
            verifyEqual(testCase, ra.attributed_via_observes, 1, ...
                'PRED''s one pyraview is attributed through the element''s observes');
            verifyEqual(testCase, ra.refused_no_donor, 0, resultDiag(result));
            probe = findById(docs, depValue(obs, 'instrument_id'));
            verifyEqual(testCase, depValue(obs, 'entity_id'), organism.base.id, ...
                ['pyraview''s observation is not about the specimen. ' ...
                 resultDiag(result)]);
            verifyNotEmpty(testCase, probe, ...
                'pyraview''s observation names no probe as its instrument (T7)');
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
            % did-schema #88: the session is an `entity` of type session
            % (T1) whose base.id IS the session id; every other document
            % names it through its `session_id` edge.
            sessionDoc = findEntity(migrated, 'session');
            assertNotEmpty(testCase, sessionDoc, ...
                ['no entity of type session in the migrated database -- ' ...
                 'ndi.session.dir has nothing to identify the session by']);
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), ...
                sessionDoc.base.id);

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
            % did-schema #88: a subject is an `entity` (T1), so its handle is
            % entity.local_identifier (subject.local_identifier before #88).
            sub = subs{1}.document_properties;
            assertTrue(testCase, isfield(sub, 'entity') ...
                && isfield(sub.entity, 'local_identifier') ...
                && ~isempty(sub.entity.local_identifier), ...
                ['the subject read back has no entity.local_identifier -- ' ...
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

            % ---- getsubjects: THE ANIMAL, NOT THE PROBES ------------------
            % did-schema #88: the two probes are entities of type DEVICE, so
            % `isa subject` (the biological entity types, ndi.v2.subjectTypes)
            % no longer sweeps them in; before #88 they were `subject`
            % documents and getsubjects had to drop them. Either way the
            % answer is v1's: biological subjects only (Jess Haley,
            % 2026-10-21), the animal and not the probes.
            subIds = cellfun(@(d) char(d.id()), subs, 'UniformOutput', false);
            elIds = ndi.vintage.elementSubjectIds(s);
            assertEqual(testCase, numel(elIds), 2, ...
                'PRED holds 2 elements, each with an `ndi element class` assertion');
            verifyFalse(testCase, any(ismember(elIds, subIds)), ...
                'an element (a device entity) came back from `isa subject`');
            gs = s.getsubjects();
            gsIds = cellfun(@(d) char(d.id()), gs, 'UniformOutput', false);
            verifyFalse(testCase, any(ismember(elIds, gsIds)), ...
                'getsubjects returned a probe');
            verifyEqual(testCase, sort(gsIds), sort(subIds), ...
                'getsubjects and `isa subject` disagree');
            verifyEqual(testCase, numel(gs), 1, sprintf( ...
                'getsubjects returned %d; PRED holds 1 animal', numel(gs)));
        end

        function testTheTimeReferenceFamilyIsLegal(testCase)
            % `time_reference_id` is a family (`multiple`) whose members must
            % differ by `value.clock` on the referenced document
            % (did-schema #88 interaction.json, time_reference_model CHANGE 5).
            % Pre-#88 PRED's pyraview carried TWO members (a session anchor
            % with no clock and the epoch anchor on dev_local_time), and this
            % test was where that rule first had two members to compare. On
            % #88 the session is the `session_id` edge, not a time reference,
            % so the family's size is printed and the uniqueness is asserted
            % over whatever members there are; one member is reported as
            % such, never as a pass of the two-member case.
            [result, bodies] = runPredMigrate(testCase);
            docs = destinationBodies(result.destination);
            obs = pyraviewObservation(testCase, docs, bodies);
            ids = depValues(obs, 'time_reference_id');
            fprintf(['\n  TIME-REFERENCE FAMILY (PRED pyraview)\n' ...
                     '    DENOMINATOR: %d member(s)\n'], numel(ids));
            verifyNotEmpty(testCase, ids, resultDiag(result));

            clocks = cell(1, numel(ids));
            for k = 1:numel(ids)
                doc = findById(docs, ids{k});
                verifyNotEmpty(testCase, doc, sprintf( ...
                    'time_reference_id member %d names a document not in the destination', k));
                clocks{k} = clockOf(doc);
                fprintf('      %s  clock %s\n', ids{k}, clocks{k});
            end
            verifyEqual(testCase, numel(unique(clocks)), numel(clocks), sprintf( ...
                ['two members of the time_reference_id family resolve to the ' ...
                 'same clock; the rule declares it UNIQUE. %s'], resultDiag(result)));
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

function obs = pyraviewObservation(testCase, bodies, sourceBodies)
%PYRAVIEWOBSERVATION PRED's pyraview observation in the destination.
%   SELECTED BY ITS SOURCE ID. pyraview.m preserves the v1 document's id on the
%   observation it emits (base.id = the pyraview id), which is a writer-side
%   constant and touches none of the edges under test. The earlier selectors
%   (instrument_id, then base.name) each became the property under repair or
%   stopped being written (did-schema #88 writes no base.name), and the old
%   "exactly two voltage observations" premise does not hold on #88, where
%   the element's recording observation is minted per epoch from files PRED
%   does not carry.
pyrIds = {};
for k = 1:numel(sourceBodies)
    j = jsondecode(sourceBodies{k});
    if isfield(j, 'document_class') && strcmp(j.document_class.class_name, 'pyraview')
        pyrIds{end+1} = char(j.base.id); %#ok<AGROW>
    end
end
assertEqual(testCase, numel(pyrIds), 1, sprintf( ...
    'PRED should hold exactly 1 pyraview document; found %d', numel(pyrIds)));
obs = findById(bodies, pyrIds{1});
assertNotEmpty(testCase, obs, ...
    'the pyraview id is not in the destination: pyraview.m stopped preserving it');
assertEqual(testCase, obs.document_class.class_name, 'observation', ...
    'pyraview''s document is not an observation');
kinds = {obs.document_class.superclasses.class_name};
assertTrue(testCase, any(strcmp(kinds, 'voltage')), ...
    'pyraview''s observation does not list the voltage value kind');
end

function doc = findEntity(bodies, typeName)
%FINDENTITY The first `entity` whose type is TYPENAME (did-schema #88, T1).
doc = [];
for k = 1:numel(bodies)
    d = bodies{k};
    if isstruct(d) && isfield(d, 'document_class') ...
            && strcmp(d.document_class.class_name, 'entity') ...
            && isfield(d, 'entity') && isfield(d.entity, 'type') ...
            && isfield(d.entity.type, 'name') && strcmp(d.entity.type.name, typeName)
        doc = d;
        return;
    end
end
end

function v = depValues(body, name)
%DEPVALUES Every value of the edge NAME (a `multiple` edge repeats).
v = {};
if isempty(body) || ~isfield(body, 'depends_on') || ~isstruct(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value'); v{end+1} = d.value; %#ok<AGROW>
        elseif isfield(d, 'document_id'); v{end+1} = d.document_id; end %#ok<AGROW>
    end
end
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
for blk = {'relative_time_reference', 'absolute_time_reference', 'relative_reference', 'epoch_bounded_reference', 'absolute_reference'}
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
