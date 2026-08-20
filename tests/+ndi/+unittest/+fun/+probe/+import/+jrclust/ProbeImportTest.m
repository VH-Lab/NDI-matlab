classdef ProbeImportTest < matlab.unittest.TestCase
    % PROBEIMPORTTEST - Tests for ndi.fun.probe.import.jrclust.probe.
    %
    % These run headless and do not need JRCLUST: they write a JRCLUST parameter
    % file and results file for a mock probe and import them in 'dryRun' mode,
    % which exercises everything up to the database writes (locating the files,
    % checking the element, the idempotency checksum, reading the sort, rebuilding
    % the epoch boundaries, and the quality filter) without needing a session on
    % disk.
    %
    % The mock probe has two epochs of 100 samples each at 1000 Hz, so JRCLUST's
    % concatenated stream is 200 samples long and epoch 2 starts at sample 101.

    properties
        WorkDir string = ""
        S       % ndi.unittest.fun.probe.import.jrclust.MockSession
        P       % ndi.unittest.fun.probe.import.jrclust.MockProbe
        Dir     % the .JRCLUST folder for the probe
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));
            testCase.S = ndi.unittest.fun.probe.import.jrclust.MockSession(char(testCase.WorkDir));
            testCase.P = ndi.unittest.fun.probe.import.jrclust.MockProbe();
            p = ndi.fun.probe.import.jrclust.paths(testCase.S, testCase.P);
            testCase.Dir = p.directory;
            mkdir(testCase.Dir);
        end
    end

    methods (Access = private)
        function f = writePrm(testCase, varargin)
            % WRITEPRM - write a parameter file, with optional line overrides
            lines = { ...
                '% JRCLUST parameters', ...
                'recordingFormat = ''ndi'';', ...
                'sampleRate = 1000;', ...
                'nChans = 4;', ...
                'rawRecordings = {''epoch1'', ''epoch2''};', ...
                'evtWindow = [-1, 1];', ...   % 3 samples at 1000 Hz
                'ndiPath = ''/data/session'';', ...
                'ndiElementName = ''mockctx'';', ...
                'ndiElementReference = 1;'};
            lines = [lines varargin];
            f = fullfile(testCase.Dir,'jrclust.prm');
            fid = fopen(f,'w');
            fprintf(fid,'%s\n',lines{:});
            fclose(fid);
        end

        function f = writeRes(testCase, res)
            % WRITERES - write a results file; RES defaults to a curated 3-unit sort
            if nargin<2,
                res = testCase.defaultRes();
            end;
            f = fullfile(testCase.Dir,'jrclust_res.mat');
            save(f,'-struct','res');
        end

        function res = defaultRes(~)
            % Three units, annotated single / noise / multi. Unit 1 fires in both
            % epochs (samples 10 and 150), unit 2 once (20), unit 3 twice (30 and
            % 200, the last sample of epoch 2).
            res = struct();
            res.spikeTimes      = int32([10; 150; 20; 30; 200]);
            res.spikeClusters   = int32([1; 1; 2; 3; 3]);
            res.spikesByCluster = {[1;2], 3, [4;5]};
            res.clusterNotes    = {'single','noise','multi'};
            res.meanWfGlobal    = zeros(3,4,3); % 3 samples x 4 sites x 3 units
        end

        function out = dryImport(testCase, varargin)
            % DRYIMPORT - dry-run import, returning everything it printed
            S = testCase.S; %#ok<PROPLC>
            P = testCase.P; %#ok<PROPLC>
            args = varargin; %#ok<NASGU>
            out = evalc(['ndi.fun.probe.import.jrclust.probe(S, P, ' ...
                '''dryRun'', true, args{:})']);
        end
    end

    methods (Test)
        function testDryRunReportsTheUnitsItWouldImport(testCase)
            testCase.writePrm();
            testCase.writeRes();

            out = testCase.dryImport();

            % units 1 (single) and 3 (multi) pass the default quality filter
            testCase.verifySubstring(out,'Would import unit 1 as neuron mockctx_1_1');
            testCase.verifySubstring(out,'Would import unit 3 as neuron mockctx_1_3');
            testCase.verifySubstring(out,'(single, quality 1, 2 spikes)');
            testCase.verifySubstring(out,'(multi, quality 4, 2 spikes)');
            % unit 2 is noise
            testCase.verifySubstring(out,'Unit 2 (note ''noise'') skipped');
            testCase.verifySubstring(out,'Would import 2 neuron(s)');

            % a dry run touches nothing
            testCase.verifyEmpty(testCase.S.Added);
            testCase.verifyEmpty(testCase.S.Removed);
        end

        function testQualityLabelsSelectWhichUnitsAreImported(testCase)
            testCase.writePrm();
            testCase.writeRes();

            out = testCase.dryImport('qualityLabels',"noise",'qualityValues',3);

            testCase.verifySubstring(out,'Would import unit 2 as neuron mockctx_1_2');
            testCase.verifySubstring(out,'Would import 1 neuron(s)');
            testCase.verifySubstring(out,'Unit 1 (note ''single'') skipped');
        end

        function testUnannotatedUnitsAreSkipped(testCase)
            res = testCase.defaultRes();
            res.clusterNotes = {'','',''};
            testCase.writePrm();
            testCase.writeRes(res);

            out = testCase.dryImport();

            testCase.verifySubstring(out,'Unit 1 (not annotated) skipped');
            testCase.verifySubstring(out,'Would import 0 neuron(s)');
        end

        function testMissingParameterFileErrors(testCase)
            testCase.writeRes();
            testCase.verifyError(@() testCase.dryImport(), ...
                'ndi:fun:probe:import:jrclust:probe:noPrmFile');
        end

        function testMissingResultsFileErrors(testCase)
            testCase.writePrm();
            testCase.verifyError(@() testCase.dryImport(), ...
                'ndi:fun:probe:import:jrclust:probe:noResFile');
        end

        function testSortForAnotherElementIsRefused(testCase)
            testCase.writePrm('ndiElementName = ''someotherprobe'';');
            testCase.writeRes();

            testCase.verifyError(@() testCase.dryImport(), ...
                'ndi:fun:probe:import:jrclust:probe:elementMismatch');

            % ... but the check can be waived
            out = testCase.dryImport('checkElement',false);
            testCase.verifySubstring(out,'Would import 2 neuron(s)');
        end

        function testUnannotatedSortErrors(testCase)
            res = testCase.defaultRes();
            res = rmfield(res,'clusterNotes');
            testCase.writePrm();
            testCase.writeRes(res);

            testCase.verifyError(@() testCase.dryImport(), ...
                'ndi:fun:probe:import:jrclust:probe:notAnnotated');
        end

        function testEmptyRecordingListErrors(testCase)
            testCase.writePrm('rawRecordings = {};');
            testCase.writeRes();

            testCase.verifyError(@() testCase.dryImport(), ...
                'ndi:fun:probe:import:jrclust:probe:noRecordings');
        end

        function testRecordingThatIsNotAnEpochErrors(testCase)
            testCase.writePrm('rawRecordings = {''epoch1'', ''epoch99''};');
            testCase.writeRes();

            testCase.verifyError(@() testCase.dryImport(), ...
                'ndi:fun:probe:import:jrclust:probe:noSuchEpoch');
        end

        function testSpikesPastTheEndOfTheEpochsError(testCase)
            % 500 is past the end of the 200-sample stream: the sort cannot be
            % of this probe
            res = testCase.defaultRes();
            res.spikeTimes = int32([10; 150; 20; 30; 500]);
            testCase.writePrm();
            testCase.writeRes(res);

            testCase.verifyError(@() testCase.dryImport(), ...
                'ndi:fun:probe:import:jrclust:probe:sampleOutOfRange');
        end

        function testUnchangedSortIsNotReimported(testCase)
            testCase.writePrm();
            resFile = testCase.writeRes();

            md5 = ndi.fun.file.MD5(resFile);
            doc = ndi.unittest.fun.probe.import.jrclust.MockDoc.clusters('doc1', md5);
            testCase.S.SearchResults = {{doc}};

            out = testCase.dryImport();

            testCase.verifySubstring(out,'unchanged since the last import');
            testCase.verifySubstring(out,'nothing to do');
            % it stopped before reading the sort
            testCase.verifyEmpty(strfind(out,'Would import'));
        end

        function testChangedSortIsReimported(testCase)
            testCase.writePrm();
            testCase.writeRes();

            doc = ndi.unittest.fun.probe.import.jrclust.MockDoc.clusters('doc1', ...
                'a-checksum-from-an-older-sort');
            testCase.S.SearchResults = {{doc}};

            out = testCase.dryImport();

            testCase.verifySubstring(out,'Would remove 1 previously imported');
            testCase.verifySubstring(out,'Would import 2 neuron(s)');
            % a dry run removes nothing
            testCase.verifyEmpty(testCase.S.Removed);
        end

        function testForceReimportsAnUnchangedSort(testCase)
            testCase.writePrm();
            resFile = testCase.writeRes();

            md5 = ndi.fun.file.MD5(resFile);
            doc = ndi.unittest.fun.probe.import.jrclust.MockDoc.clusters('doc1', md5);
            testCase.S.SearchResults = {{doc}};

            out = testCase.dryImport('force',1);

            testCase.verifySubstring(out,'Would import 2 neuron(s)');
        end

        function testQualityLabelsAndValuesMustMatch(testCase)
            testCase.writePrm();
            testCase.writeRes();

            testCase.verifyError( ...
                @() testCase.dryImport('qualityLabels',["single","multi"],'qualityValues',1), ...
                'ndi:fun:probe:import:jrclust:probe:qualityMismatch');
        end
    end
end
