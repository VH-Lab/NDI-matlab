classdef DigitalMarkEventsTest < matlab.unittest.TestCase
    % DIGITALMARKEVENTSTEST - check events derived from digital channels
    %
    % Uses ndi.unittest.probe.MockDAQReader, whose di1 is 1 for
    % 1.0 <= t < 1.1 and 3.0 <= t < 3.1 (sampled at 1 kHz), and 0 otherwise.

    methods (Test)
        function testDimpOnOff(testCase)
            r = ndi.unittest.probe.MockDAQReader();
            [t, d] = r.readevents_epochsamples({'dimp'}, 1, {'mock'}, 0, 10);
            testCase.verifyEqual(t(:), [1.0; 1.1; 3.0; 3.1], 'AbsTol', 1e-9);
            testCase.verifyEqual(d(:), [1; -1; 1; -1]);
        end

        function testDimnOnOff(testCase)
            % dimn: "on" is the 1->0 transition and "off" is the 0->1 transition.
            % Previously the off transitions were never returned for dimn.
            r = ndi.unittest.probe.MockDAQReader();
            [t, d] = r.readevents_epochsamples({'dimn'}, 1, {'mock'}, 0, 10);
            testCase.verifyEqual(t(:), [1.0; 1.1; 3.0; 3.1], 'AbsTol', 1e-9);
            testCase.verifyEqual(d(:), [-1; 1; -1; 1]);
        end

        function testDenOnlyOn(testCase)
            r = ndi.unittest.probe.MockDAQReader();
            [t, d] = r.readevents_epochsamples({'den'}, 1, {'mock'}, 0, 10);
            testCase.verifyEqual(t(:), [1.1; 3.1], 'AbsTol', 1e-9);
            testCase.verifyEqual(d(:), [1; 1]);
        end
    end
end
