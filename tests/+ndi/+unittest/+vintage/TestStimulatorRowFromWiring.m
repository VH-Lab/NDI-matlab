classdef TestStimulatorRowFromWiring < matlab.unittest.TestCase
%TESTSTIMULATORROWFROMWIRING A migrated stimulator is found without its per-epoch Stimulator manipulation.
%
%   Decided by Jess Haley, 2026-11-09, did-schema
%   did_v2_standing_wiring_plan.md [stimulator manipulation dropped] and
%   [probe map rows compared as a set]: the body-less per-epoch Stimulator
%   manipulation DID-matlab's resolveEpochProbemap writes for each
%   stimulator row of a v1 probe map is no longer written, and the row is
%   rebuilt from the wiring relation (rig, channels) and the stimulator
%   element (name, reference, type, subject through its `observes` /
%   `derived_from` relation). ndi.vintage.ingestedEpochs reads it so
%   (A ROW WITH NO STATEMENT in its header).
%
%   THE FIXTURE is a real migrated session: three epochs of the Intan file
%   NDI ships, each with a probe map holding an n-trode `ctx` (intan1:ai1)
%   and a stimulator `stim` (intan1:di1), ingested, the .rhd files deleted,
%   migrated with ndi.migrate.local. Since DID-matlab #466 (1048e449, the
%   build of [stimulator manipulation dropped]) the migration writes no
%   Stimulator manipulation for a stimulator row its wiring relation and
%   element hold, so the tests read that session as it is (the decided
%   shape: the row from the wiring), then a copy of it with a Stimulator
%   manipulation added per epoch exactly as DID-matlab wrote it before #466
%   (resolveEpochProbemap mkManipulation: old data, which must read the
%   same), and a copy of that with the stimulator's wiring removed and the
%   manipulation kept (a stimulator row with no channels has no wiring
%   relation, so DID-matlab still writes its manipulation,
%   stimulator_manipulations_kept_no_wiring: it stays on the manipulation
%   path).
%
%   [observes retires in the second pass] (Decided by Jess Haley,
%   2026-11-17, did-schema did_v2_go_forward_class_audit.md): NDI's second
%   pass retires a stimulator's `observes` relation where a stimulus
%   presentation manipulation names it as instrument and the same animal as
%   entity; [bath manipulation retires observes] (2026-11-19): a bath
%   manipulation retires it by the same rule.
%   [stimulator subject carried as needing information], [one-field carry
%   in the migration report] (Decided by Jess Haley, 2026-11-19, did-schema
%   did_v2_standing_wiring_plan.md; carry register row carry-172): a
%   stimulator whose v1 subject no presentation, bath manipulation or
%   Stimulator manipulation names gets no `observes`; its subject is held in
%   the migration report's carried fields. This fixture's stimulator
%   presents nothing, so the migration retires its `observes` and carries
%   its subject (checked), and every read below reads it from there. More
%   copies read the other shapes: the migration record removed (so nothing
%   is carried) and one presentation manipulation (value kind `item`) per
%   wiring relation added, as the second pass leaves a stimulator that
%   presented stimuli; the same with one bath manipulation (value kind
%   `formulation`) per wiring relation instead; `observes` removed with
%   nothing added (the stored shape: the carried subject reads the same);
%   and the migration record removed with nothing added, the control that
%   shows the reads depend on the carried entry.
%
%   Filtered (never passed) when mksqlite, DID-matlab's did2 converter, a v2
%   schema set with `entity`, or NDI-compress is missing.
%   test-eta-migrate-e2e.yml runs it with all four.

    properties
        Root
        Session
        SetupError = ''
        Edited = struct('written', {{}}, 'wired', {{}}, 'added', {{}}, 'wirings', {{}})
        WithManipulation
        NoWiring
        Retired
        RetiredNothing
        Bathed
        NothingCarried
        MigrationResult
    end

    properties (Constant)
        Epochs = {'e1', 'e2', 'e3'}
        SubjectString = 'anteater27@nosuchlab.org'
    end

    methods (TestClassSetup)
        function buildIngestMigrate(testCase)
            testCase.assumeFalse(isempty(which('mksqlite')), 'mksqlite is not on the path');
            testCase.assumeFalse(isempty(which('did2.convert.v1_to_v2')), ...
                'did2.convert.v1_to_v2 (DID-matlab V2) is not on the path');
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no v2 schema set (`entity`) where did2.schema.cache looks');
            testCase.assumeFalse(isempty(which('ndi.compress.compress_ephys')), ...
                'NDI-compress is not on the path (ingest needs it)');
            testCase.Root = tempname;
            mkdir(testCase.Root);
            root = testCase.Root;
            testCase.addTeardown(@() ndi.unittest.vintage.TestStimulatorRowFromWiring.removeDir(root));
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            try
                migrated = fullfile(root, 'migrated');
                mkdir(migrated);
                [testCase.Session, testCase.MigrationResult] = P.build(migrated);
                sid = char(testCase.Session.id());
                stimId = P.stimulatorId(testCase.Session);
                written = P.manipulationIds(testCase.Session, stimId);
                wired = P.wiringIds(testCase.Session, stimId);
                % copy 1: old data, a Stimulator manipulation per wiring
                % relation of the stimulator, as DID-matlab wrote it before #466
                withManip = fullfile(root, 'with_manipulation');
                [S1, ~, added] = P.copyEdited(migrated, withManip, sid, ...
                    @(S) {}, @(S) P.oldManipulations(S, stimId));
                % copy 2: copy 1 with the stimulator's wiring removed, its
                % manipulations kept
                [S2, ids2] = P.copyEdited(withManip, fullfile(root, 'no_wiring'), sid, ...
                    @(S) P.wiringIds(S, stimId), @(S) {});
                % copy 3: the `observes` relation retired on presentations
                % (nothing carried: the migration record removed); copy 4:
                % retired with no presentation (as stored: the carried
                % subject); copy 5: retired on baths (nothing carried);
                % copy 6: nothing carried and nothing added (the control)
                gone = @(S) [reshape(P.observesIds(S, stimId), 1, []), P.migrationRecordIds(S)];
                S3 = P.copyEdited(migrated, fullfile(root, 'retired'), sid, ...
                    gone, @(S) P.presentations(S, stimId), false);
                S4 = P.copyEdited(migrated, fullfile(root, 'retired_nothing'), sid, ...
                    @(S) P.observesIds(S, stimId), @(S) {});
                S5 = P.copyEdited(migrated, fullfile(root, 'bathed'), sid, ...
                    gone, @(S) P.baths(S, stimId), false);
                S6 = P.copyEdited(migrated, fullfile(root, 'nothing_carried'), sid, ...
                    gone, @(S) {});
                testCase.WithManipulation = S1;
                testCase.NoWiring = S2;
                testCase.Retired = S3;
                testCase.RetiredNothing = S4;
                testCase.Bathed = S5;
                testCase.NothingCarried = S6;
                testCase.Edited = struct('written', {written}, 'wired', {wired}, 'added', {added}, ...
                    'wirings', {ids2});
            catch ME
                testCase.SetupError = sprintf('%s (%s)', ME.message, ME.identifier);
            end
        end
    end

    methods (Test)
        function testTheMigrationWritesNoStimulatorManipulation(testCase)
            % [stimulator manipulation dropped] (DID-matlab #466): the wired
            % stimulator's row writes no manipulation, and its wiring
            % relation is kept, one per epoch
            testCase.ready(testCase.Session);
            testCase.verifyEmpty(testCase.Edited.written, ...
                'the migration wrote a Stimulator manipulation for a row its wiring and element hold');
            testCase.verifyNumElements(testCase.Edited.wired, numel(testCase.Epochs), ...
                'the migration did not keep one stimulator wiring relation per epoch');
        end

        function testWithoutTheManipulationTheRowIsRebuiltFromTheWiring(testCase)
            % the decided shape: no statement names the stimulator, so its
            % row is rebuilt from its wiring relation and its element
            rows = testCase.stimulatorRows(testCase.ready(testCase.Session));
            testCase.verifyEqual(numel(rows), numel(testCase.Epochs), ...
                'one stimulator row per epoch, rebuilt from the wiring');
            testCase.verifyEqual(unique({rows.devicestring}), {'intan1:di1'});
            testCase.verifyEqual(unique({rows.subjectstring}), {testCase.SubjectString});
        end

        function testWithTheManipulationTheRowIsReadAsBefore(testCase)
            % old data: the manipulation names the stimulator, so its row is
            % read from it and its wiring adds no second row; the probe map
            % is the one the decided shape reads
            testCase.assertNumElements(testCase.Edited.added, numel(testCase.Epochs), ...
                'no old-data Stimulator manipulation was added (nothing measured)');
            fprintf('  added %d Stimulator manipulation(s)\n', numel(testCase.Edited.added));
            old = testCase.ready(testCase.WithManipulation);
            rows = testCase.stimulatorRows(old);
            testCase.verifyEqual(numel(rows), numel(testCase.Epochs), ...
                'one stimulator row per epoch, read from the manipulation');
            testCase.verifyEqual(unique({rows.devicestring}), {'intan1:di1'});
            testCase.verifyEqual(unique({rows.subjectstring}), {testCase.SubjectString});
            before = testCase.allRows(old);
            after = testCase.allRows(testCase.ready(testCase.Session));
            testCase.assertNumElements(after, numel(before));
            for k = 1:numel(before)
                testCase.verifyEqual(after(k).epoch_id, before(k).epoch_id);
                % [probe map rows compared as a set]
                testCase.verifyEqual(sortRows(after(k).rows), sortRows(before(k).rows), ...
                    sprintf('epoch %s: the probe map differs without the manipulation', ...
                    before(k).epoch_id));
            end
        end

        function testGetprobesFindsTheStimulatorWithoutTheManipulation(testCase)
            S = testCase.ready(testCase.Session);
            probes = S.getprobes('type', 'stimulator');
            testCase.assertNumElements(probes, 1, 'getprobes did not find the stimulator');
            testCase.verifyEqual(char(probes{1}.name), 'stim');
            testCase.verifyEqual(double(probes{1}.reference), 1);
            et = probes{1}.epochtable();
            testCase.verifyEqual(numel(et), numel(testCase.Epochs), ...
                'the stimulator does not have an epoch per ingested epoch');
            % the recording probe is unchanged
            testCase.verifyNumElements(S.getprobes('type', 'n-trode'), 1);
        end

        function testBatchedAndOneAtATimeAgreeWithoutTheManipulation(testCase)
            S = testCase.ready(testCase.Session);
            [dev, docs, cls] = testCase.navigatorDocs(S);
            P = ndi.unittest.vintage.TestIngestedReadsBatched;
            one = ndi.vintage.ingestedEpochs(S, docs, cls, 'Batch', false);
            batch = ndi.vintage.ingestedEpochs(S, docs, cls, 'Batch', true, 'UseIndex', false);
            indexed = ndi.vintage.ingestedEpochs(S, docs, cls);
            testCase.assertNumElements(one, numel(testCase.Epochs));
            for k = 1:numel(one)
                a = P.rowsOf(one(k).probemap);
                testCase.verifyEqual(P.rowsOf(batch(k).probemap), a, ...
                    sprintf('epoch %s: batched and one at a time differ', one(k).epoch_id));
                testCase.verifyEqual(P.rowsOf(indexed(k).probemap), a, ...
                    sprintf('epoch %s: the derived index and a fresh read differ', one(k).epoch_id));
                testCase.verifyTrue(any(strcmp({a.type}, 'stimulator')), ...
                    sprintf('epoch %s: no stimulator row', one(k).epoch_id));
            end
            testCase.verifyNotEmpty(dev.epochtable(), 'the system has no epochs');
        end

        function testTheIndexFollowsTheStimulatorRemovedAndReAdded(testCase)
            % the derived epoch-table index (ndi.vintage.epochIndex) against a
            % fresh read, after removing and re-adding the stimulator element
            % (ndi.unittest.migrate.epochIndexEquivalence on one probe). Its
            % rows come from the wiring alone, so an entry read while it is
            % missing must record it, or the re-added stimulator is never seen
            % by the index (Dab, TestMigrateLocalEtaDab/testEpochIndexMatchesItsSource,
            % run 44066834018).
            testCase.ready(testCase.Session);
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            dst = fullfile(testCase.Root, 'index_probe');
            S = P.copyEdited(fullfile(testCase.Root, 'migrated'), dst, ...
                char(testCase.Session.id()), @(S) {}, @(S) {});
            testCase.assumeTrue(ndi.vintage.epochIndex('available', S), ...
                'no derived-row store (DID-matlab too old?)');
            stimId = P.stimulatorId(S);
            raw = did2.database.sqlitedb(P.v2File(dst));
            cleanRaw = onCleanup(@() raw.close()); %#ok<NASGU>
            nStim = testCase.indexAgreesWithFresh(S, 'as stored');
            testCase.verifyEqual(nStim, numel(testCase.Epochs), 'as stored: one stimulator row per epoch');
            d = raw.get(stimId);
            raw.remove(stimId);
            nStim = testCase.indexAgreesWithFresh(S, 'after removing the stimulator');
            testCase.verifyEqual(nStim, 0, 'after removing the stimulator: its rows are still read');
            raw.add({d}, 'Validate', false);
            nStim = testCase.indexAgreesWithFresh(S, 'after re-adding the stimulator');
            testCase.verifyEqual(nStim, numel(testCase.Epochs), ...
                'after re-adding the stimulator: one stimulator row per epoch');
        end

        function testAStimulatorThatPresentedNothingCarriesItsSubject(testCase)
            % [stimulator subject carried as needing information], [one-field
            % carry in the migration report]: no presentation, bath or
            % Stimulator manipulation names the stimulator's subject, so the
            % second pass retires its `observes` and holds the subject in the
            % migration report's carried fields. Before those decisions
            % (Jess Haley, 2026-11-19) this test stated the `observes` was
            % kept.
            S = testCase.ready(testCase.Session);
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            stimId = P.stimulatorId(S);
            testCase.verifyEmpty(P.observesIds(S, stimId), ...
                'the migration kept the stimulator''s `observes` relation');
            r = testCase.MigrationResult.secondPass.observesRetirement;
            testCase.assertTrue(isstruct(r) && isfield(r, 'carried_element_ids'), ...
                'the migration ran no `observes` retirement');
            fprintf(['  observes retirement: %d `observes` relation(s); retired %d ' ...
                '(presentation %d, bath %d, carried %d); kept %d (observations %d)\n'], ...
                r.observes_seen, r.observes_retired, r.retired_by_presentation, ...
                r.retired_by_bath, r.retired_carried, r.observes_kept, r.kept_observation);
            testCase.verifyEqual(r.carried_element_ids, {stimId}, ...
                'the stimulator is not the one element carried');
            testCase.verifyEqual(r.carried_recorded, 1);
            [subjectId, found] = ndi.vintage.carriedSubjects(S, stimId);
            testCase.verifyTrue(found, 'the stored migration report carries no subject for the stimulator');
            % the fixture's one subject (build: ndi.subject(SubjectString)),
            % the v1 stimulator element's subject_id
            subjects = S.getsubjects();
            testCase.assertNumElements(subjects, 1, 'the migrated session does not hold its one subject');
            testCase.verifyEqual(subjectId, char(subjects{1}.id()), ...
                'the carried subject is not the stimulator''s v1 subject');
            f = ndi.vintage.elementFields(P.elementDoc(S, stimId), S);
            testCase.verifyEqual(char(f.subject_id), subjectId);
            testCase.verifyTrue(logical(f.direct), 'the stimulator reads direct false');
            % the migration report holds it ([one-field carry in the
            % migration report]: counts.carried_fields)
            mr = testCase.MigrationResult.migrationReport;
            testCase.assertTrue(isstruct(mr) && isfield(mr, 'counts'), 'no migration report');
            testCase.verifyEqual(sum(arrayfun(@(x) double(x.counts.carried_fields), mr)), 1, ...
                'the migration report does not hold one carried field');
        end

        function testRetiredObservesIsReadFromThePresentations(testCase)
            % the retired shape with nothing carried: the stimulator's
            % subject, `direct`, probe map rows and getprobes read as
            % migrated, one at a time and batched
            % (ndi.vintage.prefetchElementFields), from its presentations
            testCase.verifyReadsAsMigrated(testCase.Retired, 'presentations', ...
                @(S, stimId) ndi.unittest.vintage.TestStimulatorRowFromWiring.presentationIds(S, stimId));
        end

        function testRetiredObservesIsReadFromTheBaths(testCase)
            % [bath manipulation retires observes]: the same, from bath
            % manipulations (value kind `formulation`)
            testCase.verifyReadsAsMigrated(testCase.Bathed, 'baths', ...
                @(S, stimId) ndi.unittest.vintage.TestStimulatorRowFromWiring.bathIds(S, stimId));
        end

        function testRetiredWithNoPresentationReadsTheCarriedSubject(testCase)
            % `observes` removed and nothing added: the carried entry
            % ([one-field carry in the migration report]) reads the same
            % subject, `direct`, probe map rows and getprobes. Before that
            % decision this control lost the subject.
            testCase.verifyReadsAsMigrated(testCase.RetiredNothing, 'the carried field', ...
                @(S, stimId) {});
            S = testCase.ready(testCase.RetiredNothing);
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            [~, found] = ndi.vintage.carriedSubjects(S, P.stimulatorId(testCase.ready(testCase.Session)));
            testCase.verifyTrue(found, 'the copy holds no carried subject (nothing measured)');
        end

        function testNothingCarriedAndNothingAddedLosesTheSubject(testCase)
            % the control: without its `observes` relation, the carried
            % entry, a presentation or a bath, nothing names the stimulator's
            % subject, so the tests above measure those
            S = testCase.ready(testCase.NothingCarried);
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            stimId = P.stimulatorId(testCase.ready(testCase.Session));
            testCase.assertEmpty(P.migrationRecordIds(S), 'the copy still holds the migration record');
            [~, found] = ndi.vintage.carriedSubjects(S, stimId);
            testCase.verifyFalse(found, 'a carried subject was read with no migration record');
            f = ndi.vintage.elementFields(P.elementDoc(S, stimId), S);
            testCase.verifyEmpty(f.subject_id, ...
                'the subject was read from something other than `observes`, the carried field, a presentation or a bath');
        end

        function testWithoutTheWiringTheManipulationStillGivesTheRow(testCase)
            % a stimulator row with no channels has no wiring relation: its
            % row is read from the manipulation, with the system's name as
            % its devicestring
            testCase.assertNotEmpty(testCase.Edited.wirings, ...
                'the migration wrote no stimulator wiring to remove (nothing measured)');
            rows = testCase.stimulatorRows(testCase.ready(testCase.NoWiring));
            testCase.verifyEqual(numel(rows), numel(testCase.Epochs));
            testCase.verifyEqual(unique({rows.devicestring}), {'intan1'});
        end
    end

    methods (Access = private)
        function verifyReadsAsMigrated(testCase, copy, what, statementIds)
            % the stimulator in COPY reads as in the migrated session: its
            % fields one at a time and batched, every epoch's probe map, and
            % getprobes. STATEMENTIDS(S, stimId) are the statements it is read
            % from (asserted one per epoch when not empty)
            S0 = testCase.ready(testCase.Session);
            S = testCase.ready(copy);
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            stimId = P.stimulatorId(S0);
            testCase.assertEmpty(P.observesIds(S, stimId), 'the copy still holds `observes`');
            st = statementIds(S, stimId);
            if ~isempty(st) || ~strcmp(what, 'the carried field')
                testCase.assertNumElements(st, numel(testCase.Epochs), ...
                    sprintf('the copy holds no %s per epoch (nothing measured)', what));
            end
            fprintf('  read from %s: %d statement(s)\n', what, numel(st));
            el = P.elementDoc(S0, stimId);
            want = ndi.vintage.elementFields(el, S0);
            testCase.assertNotEmpty(want.subject_id, 'the stimulator has no subject as migrated');
            got = ndi.vintage.elementFields(P.elementDoc(S, stimId), S);
            testCase.verifyEqual(got, want, sprintf('one at a time: the stimulator reads differently from %s', what));
            scope = ndi.vintage.elementFieldsScope('open'); %#ok<NASGU>
            ndi.vintage.prefetchElementFields(S, {P.elementDoc(S, stimId)}, false);
            batched = ndi.vintage.elementFields(P.elementDoc(S, stimId), S);
            clear scope
            testCase.verifyEqual(batched, want, sprintf('batched: the stimulator reads differently from %s', what));
            before = testCase.allRows(S0);
            after = testCase.allRows(S);
            testCase.assertNumElements(after, numel(before));
            for k = 1:numel(before)
                testCase.verifyEqual(sortRows(after(k).rows), sortRows(before(k).rows), ...
                    sprintf('epoch %s: the probe map differs read from %s', before(k).epoch_id, what));
            end
            probes = S.getprobes('type', 'stimulator');
            testCase.assertNumElements(probes, 1, 'getprobes did not find the stimulator');
            testCase.verifyEqual(char(probes{1}.subject_id), char(want.subject_id));
        end

        function S = ready(testCase, S)
            testCase.assertEmpty(testCase.SetupError, ...
                ['building, ingesting, migrating or copying the fixture raised: ' testCase.SetupError]);
            testCase.assertTrue(ndi.daq.reader.isv2database(S), 'the session is not on a v2 database');
        end

        function [dev, docs, cls] = navigatorDocs(testCase, S)
            dev = S.daqsystem_load('name', 'intan1');
            if iscell(dev); dev = dev{1}; end
            testCase.assertNotEmpty(dev, 'the migrated session has no intan1 system');
            nav = dev.filenavigator;
            cls = nav.epochprobemap_class;
            docs = S.database_search(ndi.vintage.ingestedQuery(nav.id(), S.id()));
            testCase.assertNumElements(docs, numel(testCase.Epochs), ...
                'the migrated session does not hold one ingestion manifest per epoch');
        end

        function nStim = indexAgreesWithFresh(testCase, S, when)
            % the index read twice (the second answers from the stored rows)
            % against a fresh read; the fresh read's stimulator rows
            [~, docs, cls] = testCase.navigatorDocs(S);
            fresh = ndi.vintage.ingestedEpochs(S, docs, cls, 'UseIndex', false);
            for pass = 1:2
                viaIndex = ndi.vintage.ingestedEpochs(S, docs, cls);
                % isequal, as ndi.unittest.migrate.epochIndexEquivalence compares
                testCase.verifyTrue(isequal(viaIndex, fresh), sprintf( ...
                    '%s, read %d: the index and a fresh read differ', when, pass));
            end
            nStim = 0;
            for k = 1:numel(fresh)
                rows = ndi.unittest.vintage.TestIngestedReadsBatched.rowsOf(fresh(k).probemap);
                if ~isempty(rows)
                    nStim = nStim + sum(strcmp({rows.type}, 'stimulator'));
                end
            end
        end

        function R = allRows(testCase, S)
            [~, docs, cls] = testCase.navigatorDocs(S);
            E = ndi.vintage.ingestedEpochs(S, docs, cls, 'UseIndex', false);
            testCase.verifyEqual(unique({E.vintage}), {'V_eta'}, ...
                'the epochs were not read from migrated manifests');
            R = struct('epoch_id', {}, 'rows', {});
            for k = 1:numel(E)
                R(end+1) = struct('epoch_id', E(k).epoch_id, ...
                    'rows', ndi.unittest.vintage.TestIngestedReadsBatched.rowsOf(E(k).probemap)); %#ok<AGROW>
            end
            [~, o] = sort({R.epoch_id});
            R = R(o);
        end

        function rows = stimulatorRows(testCase, S)
            R = testCase.allRows(S);
            rows = [R.rows];
            if isempty(rows); return; end
            rows = rows(strcmp({rows.type}, 'stimulator'));
        end
    end

    methods (Static)
        function [S, result] = build(root)
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            src = fullfile(ndi.common.PathConstants.ExampleDataFolder, 'exp1_eg_saved', ...
                'Intan_160317_125049_short.rhd');
            for k = 1:numel(P.Epochs)
                e = P.Epochs{k};
                copyfile(src, fullfile(root, [e '.rhd']));
                fid = fopen(fullfile(root, [e '.epochprobemap.ndi']), 'wt');
                fprintf(fid, 'name\treference\ttype\tdevicestring\tsubjectstring\n');
                fprintf(fid, 'ctx\t1\tn-trode\tintan1:ai1\t%s\n', P.SubjectString);
                fprintf(fid, 'stim\t1\tstimulator\tintan1:di1\t%s\n', P.SubjectString);
                fclose(fid);
            end
            S = ndi.session.dir('stimulator rows', root);
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            S.daqsystem_add(ndi.daq.system.mfdaq('intan1', nav, ndi.daq.reader.mfdaq.intan()));
            subject = ndi.subject(P.SubjectString, '');
            S.database_add(subject.newdocument());
            S.cache.clear();
            [b, msg] = S.ingest();
            assert(logical(b), 'ingest failed: %s', msg);
            % the probes' element documents (without a probe entity to wire,
            % migration carries the ingested epoch whole as v1)
            probes = S.getprobes();
            assert(numel(probes) == 2, 'expected the probes ctx and stim, found %d', numel(probes));
            for k = 1:numel(P.Epochs)
                delete(fullfile(root, [P.Epochs{k} '.rhd']));
            end
            clear S nav
            result = ndi.migrate.local(root, 'Validate', true, 'Backup', false);
            assert(isempty(result.quarantine), '%d document(s) quarantined', numel(result.quarantine));
            S = ndi.session.dir(root);
        end

        function id = stimulatorId(S)
            % the migrated stimulator elements: the probes (ndi.vintage.elementSubjectDocs
            % 'probe') whose element type is stimulator (ndi.vintage.elementFields). Not
            % elementSubjectDocs(S, 'stimulator'): that matched the "ndi element class"
            % assertion's class name, which DID-matlab no longer writes ([ndi element
            % class not kept], [element recognised by its links], Jess Haley, 2026-11-10,
            % did-schema did_v2_go_forward_class_audit.md); a probe's rebuilt class stem
            % is ndi.probe. and does not name its type.
            docs = ndi.vintage.elementSubjectDocs(S, 'probe');
            docs = docs(cellfun(@(d) strcmp(char(ndi.vintage.elementFields(d, S).type), 'stimulator'), docs));
            assert(numel(docs) == 1, 'expected one migrated stimulator element, found %d', numel(docs));
            id = char(docs{1}.id());
        end

        function ids = manipulationIds(S, stimId)
            % the per-epoch Stimulator manipulations: the stimulator is their
            % instrument and they name the rig (resolveEpochProbemap mkManipulation)
            found = S.database_search(ndi.v2.isaQuery('manipulation') & ...
                ndi.query('', 'depends_on', 'instrument_id', stimId));
            keep = cellfun(@(d) ~isempty(ndi.vintage.edgeTargets(d, 'acquisition_system_id')), found);
            ids = cellfun(@(d) char(d.id()), found(keep), 'UniformOutput', false);
        end

        function ids = wiringIds(S, stimId)
            % the stimulator's `connected to` (RO:0002170) wiring relations
            found = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
                ndi.query('', 'depends_on', 'child_id', stimId));
            keep = cellfun(@(d) ndi.unittest.vintage.TestStimulatorRowFromWiring.isWiring(d), found);
            ids = cellfun(@(d) char(d.id()), found(keep), 'UniformOutput', false);
        end

        function docs = oldManipulations(S, stimId)
            % old data: per wiring relation of the stimulator, the Stimulator
            % manipulation DID-matlab's resolveEpochProbemap wrote before #466
            % (mkManipulation, the same call): the stimulator type as variable
            % and term value, about the element's subject, the stimulator as
            % instrument, the rig as acquisition system, timed by the
            % wiring's epoch anchor
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            els = ndi.vintage.elementSubjectDocs(S, 'probe');
            els = els(cellfun(@(d) strcmp(char(d.id()), stimId), els));
            assert(numel(els) == 1, 'expected the stimulator element %s, found %d', stimId, numel(els));
            subjectId = char(ndi.vintage.elementFields(els{1}, S).subject_id);
            assert(~isempty(subjectId), 'the stimulator element has no subject');
            found = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
                ndi.query('', 'depends_on', 'child_id', stimId));
            found = found(cellfun(@(d) P.isWiring(d), found));
            typeTerm = did2.convert.registeredTerm('', 'stimulator');
            docs = cell(1, numel(found));
            for k = 1:numel(found)
                anchor = ndi.vintage.edgeTargets(found{k}, 'time_reference_id');
                rig = ndi.vintage.edgeTargets(found{k}, 'parent_id');
                assert(isscalar(anchor) && isscalar(rig), ...
                    'wiring %s does not name one anchor and one rig', char(found{k}.id()));
                m = did2.build.statement('manipulation', subjectId, typeTerm, typeTerm, ...
                    'TimeReferenceIds', anchor, 'InstrumentId', stimId, ...
                    'AcquisitionSystemId', char(rig{1}), 'SessionId', char(S.id()), ...
                    'Validate', false, 'ValueKind', 'term');
                docs{k} = did2.document(m);
            end
        end

        function ids = observesIds(S, stimId)
            % the stimulator's `observes` relations
            found = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
                ndi.v2.vocabQuery('directed_relation.relation', 'relation', 'observes') & ...
                ndi.query('', 'depends_on', 'child_id', stimId));
            ids = cellfun(@(d) char(d.id()), found, 'UniformOutput', false);
        end

        function ids = presentationIds(S, stimId)
            % the stimulus presentation manipulations (value kind `item`) by the stimulator
            found = S.database_search(ndi.v2.statementQuery('manipulation', 'item') & ...
                ndi.query('', 'depends_on', 'instrument_id', stimId));
            ids = cellfun(@(d) char(d.id()), found, 'UniformOutput', false);
        end

        function d = elementDoc(S, id)
            found = S.database_search(ndi.query('base.id', 'exact_string', id, ''));
            assert(numel(found) == 1, 'expected the element %s, found %d', id, numel(found));
            d = found{1};
        end

        function docs = presentations(S, stimId)
            % per wiring relation of the stimulator, a stimulus presentation
            % manipulation as ndi.migrate.internal.stimulusPresentationToItem
            % writes it (itemManipulation, the same did2.build.statement call):
            % the stimulator's subject as entity, the stimulator as instrument,
            % a two-stimulus playlist, timed by the wiring's epoch anchor. Built
            % with validation off and added so: the item_id edges to its
            % stimulus methods are not part of what the reader reads
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            subjectId = char(ndi.vintage.elementFields(P.elementDoc(S, stimId), S).subject_id);
            assert(~isempty(subjectId), 'the stimulator element has no subject');
            found = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
                ndi.query('', 'depends_on', 'child_id', stimId));
            found = found(cellfun(@(d) P.isWiring(d), found));
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            docs = cell(1, numel(found));
            for k = 1:numel(found)
                anchor = ndi.vintage.edgeTargets(found{k}, 'time_reference_id');
                m = did2.build.statement('manipulation', subjectId, 'visual stimulus', ...
                    struct('item', [0 1 0]), 'ValueKind', 'item', ...
                    'Method', 'visual stimulation', 'TimeReferenceIds', anchor, ...
                    'InstrumentId', stimId, 'SessionId', char(S.id()), 'Validate', false);
                docs{k} = did2.document(m);
            end
        end

        function ids = bathIds(S, stimId)
            % the bath manipulations (value kind `formulation`) by the stimulator
            found = S.database_search(ndi.v2.statementQuery('manipulation', 'formulation') & ...
                ndi.query('', 'depends_on', 'instrument_id', stimId));
            ids = cellfun(@(d) char(d.id()), found, 'UniformOutput', false);
        end

        function docs = baths(S, stimId)
            % per wiring relation of the stimulator, a bath manipulation as
            % ndi.migrate.internal.stimulusBathToBath writes it (value kind
            % `formulation`, the stimulator's subject as entity, the
            % stimulator as instrument, timed by the wiring's epoch anchor);
            % its value_id edge to a formulation is not what the reader reads,
            % so it is left out and the document added unvalidated
            P = ndi.unittest.vintage.TestStimulatorRowFromWiring;
            subjectId = char(ndi.vintage.elementFields(P.elementDoc(S, stimId), S).subject_id);
            assert(~isempty(subjectId), 'the stimulator element has no subject');
            found = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
                ndi.query('', 'depends_on', 'child_id', stimId));
            found = found(cellfun(@(d) P.isWiring(d), found));
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            docs = cell(1, numel(found));
            for k = 1:numel(found)
                anchor = ndi.vintage.edgeTargets(found{k}, 'time_reference_id');
                m = did2.build.statement('manipulation', subjectId, 'bath solution', [], ...
                    'ValueKind', 'formulation', 'TimeReferenceIds', anchor, ...
                    'InstrumentId', stimId, 'SessionId', char(S.id()), 'Validate', false);
                docs{k} = did2.document(m);
            end
        end

        function ids = migrationRecordIds(S)
            % the migration record (`migration`) and its report body
            % (`opaque_body` naming it as owner_id): removing them removes
            % the carried fields ([one-field carry in the migration report])
            % (the bodies first: each depends on its record)
            recs = S.database_search(ndi.query('', 'isa', 'migration', ''));
            ids = {};
            for k = 1:numel(recs)
                b = S.database_search(ndi.query('', 'isa', 'opaque_body', '') & ...
                    ndi.query('', 'depends_on', 'owner_id', char(recs{k}.id())));
                ids = [ids, reshape(cellfun(@(d) char(d.id()), b, 'UniformOutput', false), 1, [])]; %#ok<AGROW>
            end
            ids = [ids, reshape(cellfun(@(d) char(d.id()), recs, 'UniformOutput', false), 1, [])];
        end

        function tf = isWiring(d)
            % a directed_relation `connected to` (RO:0002170)
            tf = false;
            p = d.document_properties;
            if ~isfield(p, 'directed_relation') || ~isfield(p.directed_relation, 'relation'); return; end
            r = p.directed_relation.relation;
            tf = isstruct(r) && isfield(r, 'node') && strcmpi(char(r.node), 'RO:0002170');
        end

        function [S, ids, added] = copyEdited(srcRoot, dstRoot, sid, pick, make, validate)
            % a copy of the migrated session's .ndi under DSTROOT with the
            % documents PICK(session) names removed and the did2.documents
            % MAKE(session) returns added (validated unless VALIDATE is
            % false), reopened
            if nargin < 6
                validate = true;
            end
            mkdir(dstRoot);
            copyfile(fullfile(srcRoot, '.ndi'), fullfile(dstRoot, '.ndi'));
            for f = {'unique_reference.txt', 'reference.txt', '.migrate.lock'}
                p = fullfile(dstRoot, '.ndi', f{1});
                if isfile(p); delete(p); end
            end
            S = ndi.session.dir('stimulator rows copy', dstRoot, sid);
            ids = pick(S);
            newDocs = make(S);
            raw = did2.database.sqlitedb(ndi.unittest.vintage.TestStimulatorRowFromWiring.v2File(dstRoot));
            for k = 1:numel(ids)
                raw.remove(ids{k});
            end
            if ~isempty(newDocs) && validate
                raw.add(newDocs);
            elseif ~isempty(newDocs)
                raw.add(newDocs, 'Validate', false);
            end
            added = cellfun(@(d) char(d.get('base.id')), newDocs, 'UniformOutput', false);
            raw.close();
            clear S
            S = ndi.session.dir('stimulator rows copy', dstRoot, sid);
            S.cache.clear();
        end

        function v2file = v2File(root)
            % the v2 database file of the session at ROOT
            v2file = '';
            dbs = dir(fullfile(root, '.ndi', '*.sqlite'));
            for k = 1:numel(dbs)
                try
                    db = did2.database.sqlitedb(fullfile(dbs(k).folder, dbs(k).name));
                catch
                    continue;   % the v1 database beside it
                end
                if ~isempty(db.search(did2.query('', 'isa', 'acquisition_system')))
                    v2file = fullfile(dbs(k).folder, dbs(k).name);
                end
                db.close();
            end
            assert(~isempty(v2file), 'no v2 database under %s', root);
        end

        function removeDir(d)
            try
                if isfolder(d); rmdir(d, 's'); end
            catch
            end
        end
    end
end

function r = sortRows(r)
% probe-map rows in a fixed order ([probe map rows compared as a set])
if isempty(r); return; end
keys = arrayfun(@(x) strjoin({x.name, num2str(x.reference), x.type, x.devicestring, ...
    x.subjectstring}, char(0)), r, 'UniformOutput', false);
[~, o] = sort(keys);
r = r(o);
end
