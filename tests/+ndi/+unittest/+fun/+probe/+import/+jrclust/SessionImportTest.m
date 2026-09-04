classdef SessionImportTest < matlab.unittest.TestCase
    % SESSIONIMPORTTEST - Tests for ndi.fun.probe.import.jrclust.session, which
    % imports every probe of a session that has a JRCLUST sort.
    %
    % These run headless and do not need JRCLUST: the session holds two mock
    % probes, only one of which has been sorted, and the import runs in 'dryRun'
    % mode so nothing is written to a database.

    properties
        WorkDir string = ""
        S
        Sorted      % the probe that has a JRCLUST sort
        Unsorted    % the probe that does not
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));

            testCase.S = ndi.unittest.fun.probe.import.jrclust.MockSession(char(testCase.WorkDir));
            testCase.Sorted = ndi.unittest.fun.probe.import.jrclust.MockProbe();
            testCase.Unsorted = ndi.unittest.fun.probe.import.jrclust.MockProbe();
            testCase.Unsorted.name = 'unsortedctx';
            testCase.S.Probes = {testCase.Sorted, testCase.Unsorted};

            % give the first probe a curated sort
            p = ndi.fun.probe.import.jrclust.paths(testCase.S, testCase.Sorted);
            mkdir(p.directory);

            fid = fopen(p.prmFile,'w');
            fprintf(fid,'%s\n', ...
                'recordingFormat = ''ndi'';', ...
                'sampleRate = 1000;', ...
                'nChans = 4;', ...
                'rawRecordings = {''epoch1'', ''epoch2''};', ...
                'evtWindow = [-1, 1];', ...
                'ndiElementName = ''mockctx'';', ...
                'ndiElementReference = 1;');
            fclose(fid);

            res = struct();
            res.spikeTimes      = int32([10; 150; 30]);
            res.spikeClusters   = int32([1; 1; 2]);
            res.spikesByCluster = {[1;2], 3};
            res.clusterNotes    = {'single','noise'};
            res.meanWfGlobal    = zeros(3,4,2);
            save(p.resFile,'-struct','res');
        end
    end

    methods (Test)
        function testEveryProbeWithASortIsImported(testCase)
            S = testCase.S; %#ok<PROPLC>
            out = evalc('ndi.fun.probe.import.jrclust.session(S,''dryRun'',true)');

            testCase.verifySubstring(out,'Found 2 probe(s)');
            % the sorted probe's single unit
            testCase.verifySubstring(out,'Would import unit 1 as neuron mockctx_1_1');
            testCase.verifySubstring(out,'Would import 1 neuron(s)');
            % the unsorted probe is skipped, not imported
            testCase.verifyEmpty(strfind(out,'unsortedctx_1_'));
            testCase.verifySubstring(out,'Done importing JRCLUST results');

            testCase.verifyEmpty(testCase.S.Added);
        end

        function testQualityLabelsArePassedThrough(testCase)
            S = testCase.S; %#ok<PROPLC>
            out = evalc(['ndi.fun.probe.import.jrclust.session(S,''dryRun'',true,' ...
                '''qualityLabels'',"noise",''qualityValues'',3)']);

            testCase.verifySubstring(out,'Would import unit 2 as neuron mockctx_1_2');
            testCase.verifySubstring(out,'Would import 1 neuron(s)');
        end
    end
end
