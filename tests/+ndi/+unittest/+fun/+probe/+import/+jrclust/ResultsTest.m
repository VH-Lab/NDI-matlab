classdef ResultsTest < matlab.unittest.TestCase
    % RESULTSTEST - Tests for ndi.fun.probe.import.jrclust.results.
    %
    % These run headless and do not need JRCLUST: they write small results
    % (_res.mat) files in JRCLUST's format and check how NDI normalizes them.

    properties
        WorkDir string = ""
    end

    methods (TestMethodSetup)
        function makeWorkDir(testCase)
            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));
        end
    end

    methods (Access = private)
        function f = writeRes(testCase, res)
            f = fullfile(char(testCase.WorkDir),'jrclust_res.mat');
            save(f,'-struct','res'); % res is read by name by save()
        end
    end

    methods (Test)
        function testReadsSortedAndAnnotatedResults(testCase)
            res = struct();
            res.spikeTimes = int32([10; 20; 30; 40]);
            res.spikeClusters = int32([1; 2; 1; 2]);
            res.spikesByCluster = {[1;3],[2;4]};
            res.clusterNotes = {'single','multi'};
            res.meanWfGlobal = zeros(31,4,2);
            f = testCase.writeRes(res);

            R = ndi.fun.probe.import.jrclust.results(f);

            testCase.verifyEqual(R.spikeSamples,[10;20;30;40]);
            testCase.verifyEqual(R.unitIds,[1 2]);
            testCase.verifyEqual(R.unitLabels,["single","multi"]);
            testCase.verifyEqual(R.spikesByCluster{1},[1;3]);
            testCase.verifyEqual(R.unitCount,[2 2]);
            testCase.verifyTrue(R.hasNotes);
            testCase.verifyEqual(size(R.meanWfGlobal),[31 4 2]);
        end

        function testUnitsRebuiltFromSpikeClusters(testCase)
            % Without spikesByCluster, the units are reconstructed from the
            % per-spike assignments (and deleted spikes, marked <= 0, are left out).
            res = struct();
            res.spikeTimes = int32([5; 15; 25; 35]);
            res.spikeClusters = int32([1; -1; 2; 2]);
            res.clusterNotes = {'single','noise'};
            f = testCase.writeRes(res);

            R = ndi.fun.probe.import.jrclust.results(f);

            testCase.verifyEqual(R.unitIds,[1 2]);
            testCase.verifyEqual(R.unitCount,[1 2]);
            testCase.verifyEqual(R.spikesByCluster{2},[3;4]);
        end

        function testUnannotatedSortIsReported(testCase)
            res = struct();
            res.spikeTimes = int32([1; 2]);
            res.spikeClusters = int32([1; 1]);
            res.spikesByCluster = {[1;2]};
            f = testCase.writeRes(res);

            R = ndi.fun.probe.import.jrclust.results(f);

            testCase.verifyFalse(R.hasNotes);
            testCase.verifyEqual(R.unitLabels,"");
        end

        function testDetectedButNotSortedErrors(testCase)
            res = struct();
            res.spikeTimes = int32([1; 2]);
            f = testCase.writeRes(res);

            testCase.verifyError(@() ndi.fun.probe.import.jrclust.results(f), ...
                'ndi:fun:probe:import:jrclust:results:noClusters');
        end

        function testNoSpikesErrors(testCase)
            res = struct();
            res.somethingElse = 1;
            f = testCase.writeRes(res);

            testCase.verifyError(@() ndi.fun.probe.import.jrclust.results(f), ...
                'ndi:fun:probe:import:jrclust:results:noSpikes');
        end

        function testWaveformsCanBeSkipped(testCase)
            res = struct();
            res.spikeTimes = int32([1; 2]);
            res.spikeClusters = int32([1; 1]);
            res.spikesByCluster = {[1;2]};
            res.clusterNotes = {'single'};
            res.meanWfGlobal = ones(31,4,1);
            f = testCase.writeRes(res);

            R = ndi.fun.probe.import.jrclust.results(f,'needWaveforms',false);

            testCase.verifyEmpty(R.meanWfGlobal);
        end
    end
end
