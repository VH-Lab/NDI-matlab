classdef TestIngestedReadsBatched < matlab.unittest.TestCase
%TESTINGESTEDREADSBATCHED A migrated session's ingested epochs read in a few searches give what one epoch at a time gives.
%
%   The migrated epoch-read speed fix (Jess Haley, 2026-11-06: "Yes, build
%   the speed fix now"). On a migrated session NDI rebuilds each ingested
%   epoch's v1 view -- its id, probe map, clocks and t0_t1 -- from v2
%   documents. Read one epoch at a time that took about 13 database searches
%   per epoch (VH-Lab/NDI-matlab#785, run 41876678241). Now each kind of
%   document is read once for all of a navigator's or reader's epochs and
%   joined in memory:
%
%     ndi.vintage.ingestedEpochs(..., 'Batch', true)   ids and probe maps
%     ndi.vintage.ingestedArchives                      clocks and t0_t1
%     ndi.daq.system/buildepochtable                    uses both
%
%   THE FIXTURE is a real migrated session: three epochs of the Intan file
%   NDI ships (the file ndi.unittest.session.buildSession uses), each with
%   its own probe map -- the second has a second probe on other channels --
%   ingested with ndi.session/ingest, the .rhd files deleted, the session
%   migrated in place with ndi.migrate.local and reopened. Every test
%   compares the batched read with the per-epoch read on that session, and
%   first checks that there is something to compare.
%
%   Filtered (never passed) when mksqlite, DID-matlab's did2 converter, a v2
%   schema set with `entity`, or NDI-compress is missing.
%   test-eta-migrate-e2e.yml runs it with all four.

    properties
        Root
        Session
        SetupError = ''
    end

    properties (Constant)
        Epochs = {'e1', 'e2', 'e3'}
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
            testCase.addTeardown(@() ndi.unittest.vintage.TestIngestedReadsBatched.removeDir(root));
            try
                testCase.Session = ndi.unittest.vintage.TestIngestedReadsBatched.build(root);
            catch ME
                testCase.SetupError = sprintf('%s (%s)', ME.message, ME.identifier);
            end
        end
    end

    methods (Test)
        function testProbeMapsAreTheSame(testCase)
            [S, dev] = testCase.migrated();
            nav = dev.filenavigator;
            docs = S.database_search(ndi.vintage.ingestedQuery(nav.id(), S.id()));
            testCase.assertNumElements(docs, numel(testCase.Epochs), ...
                'the migrated session does not hold one ingestion manifest per epoch');
            one = ndi.vintage.ingestedEpochs(S, docs, nav.epochprobemap_class, 'Batch', false);
            batch = ndi.vintage.ingestedEpochs(S, docs, nav.epochprobemap_class, 'Batch', true);
            testCase.assertNumElements(batch, numel(one));
            testCase.verifyEqual(unique({one.vintage}), {'V_eta'}, ...
                'the epochs were not read from migrated manifests');
            rows = 0;
            for k = 1:numel(one)
                testCase.verifyEqual(batch(k).epoch_id, one(k).epoch_id);
                testCase.verifyEqual(batch(k).files, one(k).files);
                a = ndi.unittest.vintage.TestIngestedReadsBatched.rowsOf(one(k).probemap);
                b = ndi.unittest.vintage.TestIngestedReadsBatched.rowsOf(batch(k).probemap);
                testCase.verifyEqual(b, a, sprintf('epoch %s: the probe map differs', one(k).epoch_id));
                rows = rows + numel(a);
                fprintf('  %s: %d probe-map row(s), per epoch and batched alike\n', ...
                    one(k).epoch_id, numel(a));
            end
            % the second epoch has two probes, the others one
            testCase.verifyEqual(rows, 4, 'the probe maps hold fewer rows than were ingested');
        end

        function testEpochClocksAreTheSame(testCase)
            [S, dev] = testCase.migrated();
            et = dev.epochtable();
            testCase.assertNumElements(et, numel(testCase.Epochs));
            ids = {et.epoch_id};
            M = ndi.vintage.ingestedArchives(S, dev.daqreader.id(), ids);
            testCase.verifyEqual(M.Count, uint64(numel(ids)), ...
                'ingestedArchives did not read every epoch');
            for k = 1:numel(ids)
                A = ndi.vintage.ingestedArchive(S, dev.daqreader.id(), ids{k}, 'Channels', false);
                testCase.assertNotEmpty(A.epochclock, ['no clock: ' A.clock_problem]);
                testCase.assertTrue(isKey(M, ids{k}), ['not read at once: ' ids{k}]);
                B = M(ids{k});
                testCase.verifyEqual(B.epochclock, A.epochclock);
                testCase.verifyEqual(B.t0_t1, A.t0_t1);
                testCase.verifyEqual(B.clock_problem, A.clock_problem);
                testCase.verifyEqual(sort(B.bodies.keys), sort(A.bodies.keys));
                for f = A.bodies.keys
                    testCase.verifyEqual(B.bodies(f{1}).doc.id(), A.bodies(f{1}).doc.id());
                    testCase.verifyEqual(B.bodies(f{1}).n, A.bodies(f{1}).n);
                    testCase.verifyEqual(B.bodies(f{1}).chunk, A.bodies(f{1}).chunk);
                end
            end
        end

        function testTheEpochTableIsTheSame(testCase)
            % the system's epoch table, built with the batched reads, holds
            % the clock and t0_t1 the system reports one epoch at a time and
            % the probe map the navigator reads one epoch at a time
            [S, dev] = testCase.migrated();
            S.cache.clear();
            m = dev.daqreader.ingested2epochs_t0t1_epochclock(S, testCase.ingestedIds(dev));
            testCase.verifyEqual(m.v2epochclock.Count, uint64(numel(testCase.Epochs)), ...
                'the epoch table would not use the batched clocks');
            et = dev.epochtable();
            testCase.assertNumElements(et, numel(testCase.Epochs));
            nav = dev.filenavigator;
            for i = 1:numel(et)
                ec = dev.epochclock(i);
                testCase.verifyEqual(cellfun(@(c) c.type, et(i).epoch_clock, 'UniformOutput', false), ...
                    cellfun(@(c) c.type, ec, 'UniformOutput', false), ...
                    sprintf('epoch %s: the clocks differ', et(i).epoch_id));
                testCase.verifyEqual(et(i).t0_t1, dev.t0_t1(i), ...
                    sprintf('epoch %s: t0_t1 differs', et(i).epoch_id));
                d = nav.getepochingesteddoc(et(i).underlying_epochs(1).underlying);
                one = ndi.vintage.ingestedEpochs(S, {d}, nav.epochprobemap_class, 'Batch', false);
                testCase.verifyEqual(one.epoch_id, et(i).epoch_id, ...
                    'getepochingesteddoc found another epoch''s manifest');
                testCase.verifyEqual( ...
                    ndi.unittest.vintage.TestIngestedReadsBatched.rowsOf(et(i).epochprobemap), ...
                    ndi.unittest.vintage.TestIngestedReadsBatched.rowsOf(one.probemap), ...
                    sprintf('epoch %s: the probe map differs', et(i).epoch_id));
            end
        end

        function testFewerSearchesThanOneEpochAtATime(testCase)
            % report the database searches per epoch, one at a time and
            % batched; the batched count does not grow with the epochs
            [S, dev] = testCase.migrated();
            nav = dev.filenavigator;
            docs = S.database_search(ndi.vintage.ingestedQuery(nav.id(), S.id()));
            ids = testCase.ingestedIds(dev);
            P = ndi.unittest.vintage.TestIngestedReadsBatched;
            nOne = P.countSearches(@() P.readOneAtATime(S, docs, nav, dev, ids));
            nAll = P.countSearches(@() P.readBatched(S, docs, nav, dev, ids));
            fprintf('  database_search calls for %d epoch(s): %d one epoch at a time, %d batched\n', ...
                numel(docs), nOne, nAll);
            testCase.verifyGreaterThan(nOne, 0, 'the profiler counted no searches');
            testCase.verifyLessThan(nAll, nOne);
        end
    end

    methods (Access = private)
        function [S, dev] = migrated(testCase)
            testCase.assertEmpty(testCase.SetupError, ...
                ['building, ingesting or migrating the fixture raised: ' testCase.SetupError]);
            S = testCase.Session;
            testCase.assertTrue(ndi.daq.reader.isv2database(S), 'the session is not on a v2 database');
            dev = S.daqsystem_load('name', 'intan1');
            if iscell(dev); dev = dev{1}; end
            testCase.assertNotEmpty(dev, 'the migrated session has no intan1 system');
        end

        function ids = ingestedIds(~, dev)
            et = dev.filenavigator.epochtable();
            ids = {};
            for i = 1:numel(et)
                files = et(i).underlying_epochs(1).underlying;
                if ndi.file.navigator.isingested(files)
                    ids{end+1} = ndi.file.navigator.ingestedfiles_epochid(files); %#ok<AGROW>
                end
            end
        end
    end

    methods (Static)
        function S = build(root)
            % three epochs of the Intan file, each with its probe map; the
            % second also wires a probe ctx2 to ai2-3
            P = ndi.unittest.vintage.TestIngestedReadsBatched;
            src = fullfile(ndi.common.PathConstants.ExampleDataFolder, 'exp1_eg_saved', ...
                'Intan_160317_125049_short.rhd');
            for k = 1:numel(P.Epochs)
                e = P.Epochs{k};
                copyfile(src, fullfile(root, [e '.rhd']));
                fid = fopen(fullfile(root, [e '.epochprobemap.ndi']), 'wt');
                fprintf(fid, 'name\treference\ttype\tdevicestring\tsubjectstring\n');
                fprintf(fid, 'ctx\t1\tn-trode\tintan1:ai1\tanteater27@nosuchlab.org\n');
                if k == 2
                    fprintf(fid, 'ctx2\t1\tn-trode\tintan1:ai2-3\tanteater27@nosuchlab.org\n');
                end
                fclose(fid);
            end
            S = ndi.session.dir('batched', root);
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            S.daqsystem_add(ndi.daq.system.mfdaq('intan1', nav, ndi.daq.reader.mfdaq.intan()));
            subject = ndi.subject('anteater27@nosuchlab.org', '');
            S.database_add(subject.newdocument());
            S.cache.clear();
            [b, msg] = S.ingest();
            assert(logical(b), 'ingest failed: %s', msg);
            % the probes' element documents: without a probe entity to wire,
            % migration carries the ingested epoch whole as v1
            % (resolveEpochProbemap rows_unwirable), and nothing migrated
            % would be read
            probes = S.getprobes();
            assert(numel(probes) == 2, 'expected the probes ctx and ctx2, found %d', numel(probes));
            for k = 1:numel(P.Epochs)
                delete(fullfile(root, [P.Epochs{k} '.rhd']));
            end
            clear S nav
            result = ndi.migrate.local(root, 'Validate', true, 'Backup', false);
            assert(isempty(result.quarantine), '%d document(s) quarantined', numel(result.quarantine));
            S = ndi.session.dir(root);
        end

        function readOneAtATime(S, docs, nav, dev, ids)
            ndi.vintage.ingestedEpochs(S, docs, nav.epochprobemap_class, 'Batch', false);
            for k = 1:numel(ids)
                ndi.vintage.ingestedArchive(S, dev.daqreader.id(), ids{k}, 'Channels', false);
            end
        end

        function readBatched(S, docs, nav, dev, ids)
            ndi.vintage.ingestedEpochs(S, docs, nav.epochprobemap_class, 'Batch', true);
            ndi.vintage.ingestedArchives(S, dev.daqreader.id(), ids);
        end

        function r = rowsOf(pm)
            % a probe map as rows of its five fields, comparable with isequal
            r = struct('name', {}, 'reference', {}, 'type', {}, 'devicestring', {}, ...
                'subjectstring', {});
            for k = 1:numel(pm)
                r(end+1) = struct('name', char(pm(k).name), 'reference', double(pm(k).reference), ...
                    'type', char(pm(k).type), 'devicestring', char(pm(k).devicestring), ...
                    'subjectstring', char(pm(k).subjectstring)); %#ok<AGROW>
            end
        end

        function n = countSearches(f)
            % the number of ndi.session/database_search calls F makes
            profile('clear');
            profile('on');
            c = onCleanup(@() profile('off'));
            f();
            profile('off');
            info = profile('info');
            names = {info.FunctionTable.FunctionName};
            hit = endsWith(names, 'database_search') & contains(names, 'session');
            n = sum([info.FunctionTable(hit).NumCalls]);
        end

        function removeDir(d)
            try
                if isfolder(d); rmdir(d, 's'); end
            catch
            end
        end
    end
end
