classdef ingestCompareTest < ndi.unittest.session.buildSession
    % INGESTCOMPARETEST - ndi.test.ingest.compare / mfdaq_compare
    %
    %   Builds the example Intan session, copies it, ingests the copy, and
    %   compares the two: every check should pass in 'full' and 'spot' modes.
    %   Then an epoch is added to the raw session only, which the comparison
    %   must report as missing from the ingested copy.
    %
    %   Run with: results = runtests('ndi.unittest.ingestion.ingestCompareTest');
    %
    %   See also: ndi.test.ingest.compare, ndi.test.ingest.mfdaq_compare

    methods (Test)

        function testIngestedCopyMatchesRaw(testCase)
            [Sraw, Sing] = rawAndIngested(testCase);
            [b, report] = ndi.test.ingest.compare(Sraw, Sing, 'ShowProgress', false, 'Verbose', false);
            testCase.verifyTrue(b, strjoin(failureMessages(report), newline));

            checks = {report.check};
            testCase.verifyTrue(any(strcmp(checks,'channel_list')), 'The channel list should be checked.');
            analog = report(strcmp(checks,'analog_in'));
            testCase.assertNotEmpty(analog, 'analog_in should be compared.');
            % 'full' covers every sample of the epoch
            for k = 1:numel(analog)
                expected = Sraw.daqsystem_load('name','intan1').epochtimes2samples('analog_in', 1, ...
                    analog(k).epoch_id, analog(k).t0_t1);
                testCase.verifyEqual(analog(k).samples, expected(end)-expected(1)+1, ...
                    'Full mode should compare every sample.');
                testCase.verifyEqual(analog(k).maxAbsDiff, 0);
            end
        end

        function testSpotModeAndPaths(testCase)
            % Sessions may also be given as folder paths; 'spot' mode passes too.
            [Sraw, Sing] = rawAndIngested(testCase);
            [b, report] = ndi.test.ingest.compare(Sraw.path(), Sing.path(), 'Mode', 'spot', ...
                'SpotSeconds', 1, 'ShowProgress', false, 'Verbose', false);
            testCase.verifyTrue(b, strjoin(failureMessages(report), newline));
        end

        function testMfdaqCompareKeepsItsOldOutputs(testCase)
            % [B, ERRMSG] = mfdaq_compare(DAQ1, DAQ2) still works as before.
            [Sraw, Sing] = rawAndIngested(testCase);
            [b, errmsg] = ndi.test.ingest.mfdaq_compare(Sraw.daqsystem_load('name','intan1'), ...
                Sing.daqsystem_load('name','intan1'), 'Verbose', false);
            testCase.verifyTrue(b);
            testCase.verifyEmpty(errmsg);
        end

        function testMissingEpochIsReported(testCase)
            [Sraw, Sing] = rawAndIngested(testCase);
            % an epoch that only the raw session has
            copyfile(fullfile(Sraw.path(),'Intan_160317_125049_short.rhd'), ...
                fullfile(Sraw.path(),'Intan_160317_125049_short_b.rhd'));
            copyfile(fullfile(Sraw.path(),'Intan_160317_125049_short.epochprobemap.ndi'), ...
                fullfile(Sraw.path(),'Intan_160317_125049_short_b.epochprobemap.ndi'));
            Sraw.cache.clear();

            [b, report] = ndi.test.ingest.compare(Sraw, Sing, 'ShowProgress', false, 'Verbose', false);
            testCase.verifyFalse(b, 'An epoch missing from the ingested copy should fail the comparison.');
            missing = report(strcmp({report.check},'epoch') & ~[report.ok]);
            testCase.verifyNumElements(missing, 1);
            testCase.verifySubstring(missing.message, 'missing');
        end

        function testDaqSystemNamesFilter(testCase)
            [Sraw, Sing] = rawAndIngested(testCase);
            [b, report] = ndi.test.ingest.compare(Sraw, Sing, 'DaqSystemNames', {'nosuchdaq'}, ...
                'ShowProgress', false, 'Verbose', false);
            testCase.verifyTrue(b);
            testCase.verifyEmpty(report, 'No DAQ system should be compared.');
        end
    end

    methods (Access = private)
        function [Sraw, Sing] = rawAndIngested(testCase)
            % RAWANDINGESTED - the test session and an ingested copy of it
            Sraw = testCase.Session;
            % build the epoch table first, so the epoch ids are written to disk
            % and the copy shares them
            Sraw.daqsystem_load('name','intan1').epochtable();
            rawPath = Sraw.path();
            ingPath = tempname;
            delete(Sraw);
            testCase.Session = [];
            copyfile(rawPath, ingPath);
            Sraw = ndi.session.dir('exp1', rawPath);
            Sing = ndi.session.dir('exp1', ingPath);
            testCase.Session = Sraw;
            testCase.addTeardown(@rmdir, ingPath, 's');
            [ok, msg] = Sing.ingest('ShowProgress', false);
            testCase.assertTrue(logical(ok), ['Ingestion failed: ' msg]);
        end
    end
end

function msgs = failureMessages(report)
    bad = report(~[report.ok]);
    msgs = arrayfun(@(r) [r.daqsystem ' ' r.epoch_id ' ' r.check ': ' r.message], bad, ...
        'UniformOutput', false);
    if isempty(msgs)
        msgs = {''};
    end
end
