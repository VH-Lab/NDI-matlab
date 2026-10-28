classdef ingestionProgressParallel < ndi.unittest.session.buildSession
    % INGESTIONPROGRESSPARALLEL - progress bars and opt-in parallel ingestion
    %
    %   ndi.session/ingest and ndi.daq.system/ingest report progress through
    %   ndi.gui.component.ProgressBarWindow and can compute the per-epoch
    %   documents (raw-data reads and .nbf.tgz compression) on a parallel
    %   pool, while all database writes remain serial.
    %
    %   These tests give the buildSession example a second epoch (a copy of
    %   the Intan file) so that the parallel path has more than one epoch to
    %   distribute. Every test pins the progress window to silent mode, so no
    %   figure is needed and the bars can be checked through their
    %   bookkeeping.
    %
    %   Parallel use follows NDI's parallel preferences (ndi.fun.parallelWorkers).
    %   The test that compares a parallel ingest with a serial one opens its
    %   own process pool and is skipped without the Parallel Computing Toolbox.
    %
    %   Run with: results = runtests('ndi.unittest.ingestion.ingestionProgressParallel');
    %
    %   See also: ndi.session/ingest, ndi.daq.system/ingest,
    %       ndi.daq.fun.ingestEpochDocuments

    properties
        PreviousSilentDefault
    end

    methods (TestMethodSetup)
        function addSecondEpochAndSilence(testCase)
            S = testCase.Session;
            dirname = S.path();
            copyfile(fullfile(dirname,'Intan_160317_125049_short.rhd'), ...
                fullfile(dirname,'Intan_160317_125049_short_b.rhd'));
            copyfile(fullfile(dirname,'Intan_160317_125049_short.epochprobemap.ndi'), ...
                fullfile(dirname,'Intan_160317_125049_short_b.epochprobemap.ndi'));
            S.cache.clear();

            testCase.PreviousSilentDefault = ndi.gui.component.ProgressBarWindow.silentModeDefault();
            ndi.gui.component.ProgressBarWindow.silentModeDefault(true);
            testCase.addTeardown(@() ndi.gui.component.ProgressBarWindow.silentModeDefault( ...
                testCase.PreviousSilentDefault));
        end
    end

    methods (Test)

        function testDefaultIngestStillWorks(testCase)
            % A call with no options behaves as before: everything ingested.
            S = testCase.Session;
            [b, msg] = S.ingest();
            testCase.verifyTrue(logical(b), ['Ingestion failed: ' msg]);
            testCase.verifyEqual(numel(ingestedEpochDocs(S)), 2, ...
                'Both epochs should have an ingested daqreader document.');
            testCase.verifyTrue(logical(S.isIngested()), ...
                'The session should report itself as fully ingested.');
        end

        function testProgressBarReachesCompletion(testCase)
            S = testCase.Session;
            w = ndi.gui.component.ProgressBarWindow('ingest test', ...
                'Silent', true, 'AutoDelete', false, 'GrabMostRecent', false);
            testCase.addTeardown(@() deleteIfValid(w));

            [b, msg] = S.ingest('ProgressBar', w, 'ProgressBarTag', 'sessionBar');
            testCase.verifyTrue(logical(b), ['Ingestion failed: ' msg]);

            barNum = w.getBarNum('sessionBar');
            testCase.assertNotEmpty(barNum, 'The session-level bar should exist.');
            testCase.verifyEqual(w.ProgressBars(barNum).Progress, 1, ...
                'The session-level bar should reach 100%.');
            testCase.verifyEqual(w.ProgressBars(barNum).State, 'Complete');

            % the per-daq-system bar was added to the same window and closed
            % itself on completion
            otherBars = setdiff(1:numel(w.ProgressBars), barNum);
            testCase.verifyNumElements(otherBars, 1, ...
                'One bar should have been added for the single daq system.');
            testCase.verifyEqual(w.ProgressBars(otherBars).State, 'Closed');
            testCase.verifyEqual(w.ProgressBars(otherBars).Progress, 1);
        end

        function testShowProgressFalseAddsNoBars(testCase)
            S = testCase.Session;
            w = ndi.gui.component.ProgressBarWindow('ingest test', ...
                'Silent', true, 'AutoDelete', false, 'GrabMostRecent', false);
            testCase.addTeardown(@() deleteIfValid(w));

            [b, msg] = S.ingest('ShowProgress', false, 'ProgressBar', w);
            testCase.verifyTrue(logical(b), ['Ingestion failed: ' msg]);
            testCase.verifyEmpty(w.ProgressBars, ...
                'No bars should be added when ShowProgress is false.');
        end

        function testProgressFcnCalledOncePerEpoch(testCase)
            S = testCase.Session;
            dev = S.daqsystem_load('name','intan1');
            et = dev.epochtable();
            epochFiles = arrayfun(@(e) e.underlying_epochs.underlying, et, 'UniformOutput', false);
            epochIds = {et.epoch_id};

            calls = containers.Map('KeyType','double','ValueType','any');
            progressFcn = @(numDone, numTotal) recordCall(calls, numDone, numTotal);

            docsPerEpoch = ndi.daq.fun.ingestEpochDocuments(dev.daqreader, ...
                dev.daqmetadatareader, epochFiles(:)', epochIds, 'ProgressFcn', progressFcn);

            testCase.verifyNumElements(docsPerEpoch, numel(et));
            reported = cell2mat(calls.values(num2cell(1:double(calls.Count)))');
            numDone = reported(:,1);
            testCase.verifyEqual(reported(:,2), repmat(numel(et), numel(numDone), 1), ...
                'Every call should report the total number of epochs.');
            testCase.verifyEqual(numDone(numDone==round(numDone))', 1:numel(et), ...
                'Each whole number of epochs should be reported exactly once, in order.');
            testCase.verifyTrue(all(diff(numDone) > 0), ...
                'Progress should only move forward.');
            testCase.verifyTrue(any(numDone ~= round(numDone)), ...
                'The mfdaq reader should report progress within each epoch.');
            testCase.verifyEqual(numDone(end), numel(et), ...
                'The last call should report all epochs done.');
            for k = 1:numel(docsPerEpoch)
                testCase.verifyEqual(docsPerEpoch{k}{1}.document_properties.epochid.epochid, ...
                    epochIds{k}, 'Documents should be returned in epoch order.');
            end
        end

        function testReaderReportsWithinEpochProgress(testCase)
            % ndi.daq.reader.mfdaq/ingest_epochfiles reports the fraction of the
            % epoch done after each segment: starting at 0, never going back,
            % and ending at 1.
            S = testCase.Session;
            dev = S.daqsystem_load('name','intan1');
            et = dev.epochtable();
            fractions = containers.Map('KeyType','double','ValueType','double');
            d = dev.daqreader.ingest_epochfiles(et(1).underlying_epochs.underlying, ...
                et(1).epoch_id, 'ProgressFcn', @(f) recordFraction(fractions, f));
            testCase.verifyClass(d, 'ndi.document');
            f = cell2mat(fractions.values(num2cell(1:double(fractions.Count))));
            testCase.verifyGreaterThan(numel(f), 2, 'Expected a report per segment.');
            testCase.verifyEqual(f(1), 0, 'Progress should start at 0.');
            testCase.verifyEqual(f(end), 1, 'Progress should end at 1.');
            testCase.verifyTrue(all(diff(f) >= 0), 'Progress should never go back.');
            testCase.verifyTrue(all(f >= 0 & f <= 1));
        end

        function testPlanAndSegmentsMatchIngestEpochfiles(testCase)
            % The parallel path builds each epoch from INGEST_EPOCHFILES_PLAN,
            % INGEST_SEGMENT and INGEST_ATTACH_SEGMENTS. Done by hand here (no
            % pool needed), that must give the same document as
            % INGEST_EPOCHFILES: the same files, in the same order, holding the
            % same data.
            S = testCase.Session;
            dev = S.daqsystem_load('name','intan1');
            et = dev.epochtable();
            ef = et(1).underlying_epochs.underlying;
            reader = dev.daqreader;

            dSerial = reader.ingest_epochfiles(ef, et(1).epoch_id);

            [d, plan] = reader.ingest_epochfiles_plan(ef, et(1).epoch_id);
            testCase.verifyNotEmpty(plan, 'The example epoch has data segments to write.');
            testCase.verifyEqual(sum([plan.weight]), 1, 'AbsTol', 1e-12, ...
                'Segment weights should sum to the whole epoch.');
            files = cell(1,numel(plan));
            for t = numel(plan):-1:1 % any order: segments are independent
                files{t} = reader.ingest_segment(ef, plan(t));
            end
            dPlanned = ndi.daq.reader.mfdaq.ingest_attach_segments(d, plan, files);

            namesSerial = {dSerial.document_properties.files.file_info.name};
            namesPlanned = {dPlanned.document_properties.files.file_info.name};
            testCase.verifyEqual(namesPlanned, namesSerial, ...
                'The planned document should list the same files in the same order.');

            for i = 1:numel(namesSerial)
                if ~startsWith(namesSerial{i}, 'ai_')
                    continue;
                end
                a = expandFile(dSerial, i);
                b = expandFile(dPlanned, i);
                testCase.verifyEqual(b, a, ['Segment ' namesSerial{i} ' should hold the same data.']);
            end
        end

        function testForcedSerialDoesNotUsePool(testCase)
            % NumberOfWorkers 0 on the helper always runs in the client,
            % whatever pool or preferences exist.
            S = testCase.Session;
            dev = S.daqsystem_load('name','intan1');
            et = dev.epochtable();
            epochFiles = arrayfun(@(e) e.underlying_epochs.underlying, et, 'UniformOutput', false);
            [docsPerEpoch, usedParallel] = ndi.daq.fun.ingestEpochDocuments(dev.daqreader, ...
                dev.daqmetadatareader, epochFiles(:)', {et.epoch_id}, 'NumberOfWorkers', 0);
            testCase.verifyFalse(usedParallel);
            testCase.verifyNumElements(docsPerEpoch, numel(et));
        end

        function testNoPoolIsOpenedByDefault(testCase)
            % With Parallel.OpenPoolIfNone off (the default) and no pool open,
            % ingestion runs serially and does not start a pool.
            testCase.assumeFalse(logical(ndi.preferences.get('Parallel.OpenPoolIfNone')), ...
                'Only meaningful when Parallel.OpenPoolIfNone is false.');
            testCase.assumeTrue(~hasParallelToolbox() || isempty(gcp('nocreate')), ...
                'Only meaningful when no parallel pool is open.');
            S = testCase.Session;
            [b, msg] = S.ingest('ShowProgress', false);
            testCase.verifyTrue(logical(b), ['Ingestion failed: ' msg]);
            testCase.verifyEqual(numel(ingestedEpochDocs(S)), 2);
            if hasParallelToolbox()
                testCase.verifyEmpty(gcp('nocreate'), 'ingest should not open a pool.');
            end
        end

        function testParallelMatchesSerial(testCase)
            % Two copies of the same session: one ingested with no pool, one
            % with a process pool open (which the default preferences use).
            % The ingested documents, the data read back from them, and the
            % progress bars must agree.
            testCase.assumeTrue(hasParallelToolbox(), ...
                'Requires the Parallel Computing Toolbox.');
            testCase.assumeEmpty(gcp('nocreate'), ...
                'Needs to control the pool itself; close any open pool first.');
            testCase.assumeFalse(logical(ndi.preferences.get('Parallel.OpenPoolIfNone')), ...
                'The serial run needs Parallel.OpenPoolIfNone to be false.');
            [S1, S2] = copySession(testCase);

            [b1, msg1] = S1.ingest('ShowProgress', false);
            testCase.verifyTrue(logical(b1), ['Serial ingestion failed: ' msg1]);

            pool = parpool('Processes', 2);
            testCase.addTeardown(@() delete(pool));
            w = ndi.gui.component.ProgressBarWindow('ingest test', ...
                'Silent', true, 'AutoDelete', false, 'GrabMostRecent', false);
            testCase.addTeardown(@() deleteIfValid(w));
            [b2, msg2] = S2.ingest('ProgressBar', w, 'ProgressBarTag', 'sessionBar');
            testCase.verifyTrue(logical(b2), ['Parallel ingestion failed: ' msg2]);

            d1 = ingestedEpochDocs(S1);
            d2 = ingestedEpochDocs(S2);
            testCase.assertEqual(numel(d2), numel(d1));
            [ids1, files1] = summarize(d1);
            [ids2, files2] = summarize(d2);
            testCase.verifyEqual(ids2, ids1, 'The same epochs should be ingested.');
            testCase.verifyEqual(files2, files1, ...
                'Each epoch should carry the same set of ingested files.');

            p1 = S1.getprobes('name','ctx');
            p2 = S2.getprobes('name','ctx');
            for k = 1:numel(ids1)
                [data1, t1] = p1{1}.readtimeseries(ids1{k}, -Inf, Inf);
                [data2, t2] = p2{1}.readtimeseries(ids1{k}, -Inf, Inf);
                testCase.verifyEqual(data2, data1, 'Ingested data should match.');
                testCase.verifyEqual(t2, t1, 'Ingested time should match.');
            end

            % progress reached completion through the DataQueue path
            barNum = w.getBarNum('sessionBar');
            testCase.assertNotEmpty(barNum);
            testCase.verifyEqual(w.ProgressBars(barNum).Progress, 1);
            otherBars = setdiff(1:numel(w.ProgressBars), barNum);
            testCase.verifyEqual(w.ProgressBars(otherBars).Progress, 1, ...
                'The daq system bar should reach 100% in parallel mode too.');
        end
    end

    methods (Access = private)
        function [S1, S2] = copySession(testCase)
            % COPYSESSION - return the test session and an independent copy of it
            S1 = testCase.Session;
            S1_path = S1.path();
            S2_path = tempname;
            delete(S1);
            testCase.Session = [];
            copyfile(S1_path, S2_path);
            S1 = ndi.session.dir('exp1', S1_path);
            S2 = ndi.session.dir('exp1', S2_path);
            testCase.Session = S1;
            testCase.addTeardown(@rmdir, S2_path, 's');
        end
    end
end

function d = ingestedEpochDocs(S)
    d = S.database_search(ndi.query('','isa','daqreader_mfdaq_epochdata_ingested'));
end

function [ids, files] = summarize(d)
    % SUMMARIZE - epoch ids and sorted file names, ordered by epoch id
    ids = cellfun(@(x) x.document_properties.epochid.epochid, d, 'UniformOutput', false);
    [ids, order] = sort(ids);
    files = cell(size(ids));
    for k = 1:numel(order)
        files{k} = sort({d{order(k)}.document_properties.files.file_info.name});
    end
end

function tf = hasParallelToolbox()
    tf = ~isempty(ver('parallel')) && license('test','Distrib_Computing_Toolbox');
end

function data = expandFile(d, i)
    % EXPANDFILE - decompress the I-th (ephys) file attached to document D
    location = d.document_properties.files.file_info(i).locations(1).location;
    % expand_ephys takes the name without the .nbf.tgz extension
    data = ndi.compress.expand_ephys(extractBefore(location, '.nbf.tgz'));
end

function recordCall(calls, numDone, numTotal)
    % keyed by call order, so repeated or fractional values are all kept
    calls(double(calls.Count)+1) = [numDone numTotal];
end

function recordFraction(fractions, f)
    fractions(double(fractions.Count)+1) = f;
end

function deleteIfValid(w)
    if ~isempty(w) && isvalid(w)
        delete(w);
    end
end
