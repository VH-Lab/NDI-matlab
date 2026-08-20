classdef EpochBoundsTest < matlab.unittest.TestCase
    % EPOCHBOUNDSTEST - Tests for ndi.fun.probe.import.jrclust.epochbounds and
    % .splitspikes, the arithmetic that maps JRCLUST's concatenated sample stream
    % back onto NDI epochs.
    %
    % The mock probe has two epochs of 100 samples each at 1000 Hz, so the stream
    % is 200 samples long, epoch 1 holds global samples 1..100 and epoch 2 holds
    % 101..200.

    properties
        P   % ndi.unittest.fun.probe.import.jrclust.MockProbe
    end

    methods (TestMethodSetup)
        function makeProbe(testCase)
            testCase.P = ndi.unittest.fun.probe.import.jrclust.MockProbe();
        end
    end

    methods (Test)
        function testBoundsComeFromTheProbesEpochs(testCase)
            E = ndi.fun.probe.import.jrclust.epochbounds(testCase.P, ...
                {'epoch1','epoch2'});

            testCase.verifyEqual(E.counts,[100;100]);
            testCase.verifyEqual(E.bounds,[0;100;200]);
            testCase.verifyEqual(E.totalSamples,200);
            testCase.verifyEqual(E.epochIds,{'epoch1','epoch2'});
            testCase.verifyEqual(E.t0_t1{1},[0 0.099]);
            testCase.verifyEqual(E.clock{1}.type,'dev_local_time');
        end

        function testASubsetOfEpochsCanBeSorted(testCase)
            % JRCLUST sorts exactly the recordings the parameter file lists, in
            % that order - not necessarily every epoch of the probe
            E = ndi.fun.probe.import.jrclust.epochbounds(testCase.P,{'epoch2'});

            testCase.verifyEqual(E.epochIds,{'epoch2'});
            testCase.verifyEqual(E.bounds,[0;100]);
            testCase.verifyEqual(E.totalSamples,100);
        end

        function testRecordingThatIsNotAnEpochErrors(testCase)
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.epochbounds( ...
                testCase.P,{'epoch1','nosuchepoch'}), ...
                'ndi:fun:probe:import:jrclust:probe:noSuchEpoch');
        end

        function testEpochWithoutALocalClockErrors(testCase)
            testCase.P.clockType = 'no_time';
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.epochbounds( ...
                testCase.P,{'epoch1'}), ...
                'ndi:fun:probe:import:jrclust:probe:noClock');
        end

        function testSpikesAreDividedAtTheEpochBoundary(testCase)
            % the first and last sample of each epoch, on both sides of the seam
            ls = ndi.fun.probe.import.jrclust.splitspikes([0;100;200], ...
                [1;100;101;200]);

            testCase.verifyEqual(numel(ls),2);
            testCase.verifyEqual(ls{1},[1;100]);   % epoch 1, unchanged
            testCase.verifyEqual(ls{2},[1;100]);   % epoch 2, shifted back by 100
        end

        function testEpochsWithoutSpikesAreEmpty(testCase)
            ls = ndi.fun.probe.import.jrclust.splitspikes([0;100;200],[5;10]);

            testCase.verifyEqual(ls{1},[5;10]);
            testCase.verifyEmpty(ls{2});
        end

        function testSpikeOrderIsPreserved(testCase)
            ls = ndi.fun.probe.import.jrclust.splitspikes([0;100;200], ...
                [150;10;120]);

            testCase.verifyEqual(ls{1},10);
            testCase.verifyEqual(ls{2},[50;20]); % in the order they were given
        end

        function testSpikesOutsideTheStreamAreNotAssigned(testCase)
            % the caller checks this range and errors; splitspikes just drops them
            ls = ndi.fun.probe.import.jrclust.splitspikes([0;100;200],[0;500]);

            testCase.verifyEmpty(ls{1});
            testCase.verifyEmpty(ls{2});
        end
    end
end
