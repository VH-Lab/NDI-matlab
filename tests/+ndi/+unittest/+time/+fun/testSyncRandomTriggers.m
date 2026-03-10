classdef testSyncRandomTriggers < matlab.unittest.TestCase
% TESTSYNCRANDOMTRIGGERS - Unit test for ndi.time.fun.syncRandomTriggers
%
% This test suite verifies the robustness of the sparse fingerprinting 
% synchronization algorithm under various real-world conditions.

    properties
        Tolerance = 0.002;
    end

    methods (Test)

        function testPerfectMatch(testCase)
            % Test case where T1 and T2 are perfectly aligned with a simple shift
            true_shift = 5.23;
            true_scale = 1.0;
            
            % Generate random intervals (avg 10 Hz)
            dt = 0.1 + 0.5 * rand(100, 1);
            t2 = cumsum(dt);
            t1 = true_shift + true_scale * t2;
            
            [shift, scale] = ndi.time.fun.syncRandomTriggers(t1, t2, 'alignmentTolerance', testCase.Tolerance);
            
            testCase.verifyEqual(scale, true_scale, 'RelTol', 1e-10);
            testCase.verifyEqual(shift, true_shift, 'AbsTol', 1e-10);
        end

        function testClockDrift(testCase)
            % Test case with typical hardware clock drift (e.g., 0.1%)
            true_shift = -10.5;
            true_scale = 1.001; % 0.1% drift
            
            dt = 0.05 + 0.2 * rand(200, 1);
            t2 = cumsum(dt);
            t1 = true_shift + true_scale * t2;
            
            [shift, scale] = ndi.time.fun.syncRandomTriggers(t1, t2, 'alignmentTolerance', testCase.Tolerance);
            
            testCase.verifyEqual(scale, true_scale, 'RelTol', 1e-8);
            testCase.verifyEqual(shift, true_shift, 'AbsTol', 1e-8);
        end

        function testMissingPulses(testCase)
            % Test robustness when one device drops 5% of pulses
            true_shift = 100.0;
            true_scale = 1.00005;
            
            dt = 0.1 * rand(500, 1) + 0.05;
            t2_full = cumsum(dt);
            t1_full = true_shift + true_scale * t2_full;
            
            % Randomly drop 25 pulses from Device 2
            keep_idx = sort(randperm(length(t2_full), 475));
            t2_dropped = t2_full(keep_idx);
            
            [shift, scale] = ndi.time.fun.syncRandomTriggers(t1_full, t2_dropped, 'alignmentTolerance', testCase.Tolerance);
            
            testCase.verifyFalse(isnan(scale), 'Should find a match despite dropped pulses');
            testCase.verifyEqual(scale, true_scale, 'RelTol', 1e-6);
            testCase.verifyEqual(shift, true_shift, 'AbsTol', 1e-6);
        end

        function testPartialOverlap(testCase)
            % Device 1 recorded for 60s, Device 2 for 60s, but only overlap for 10s
            % [D1: 0-60] [D2: 50-110] -> Overlap is 10s
            
            dt = 0.1 * rand(1000, 1) + 0.05;
            t_master = cumsum(dt);
            
            % Device 1 is the first 400 pulses
            t1 = t_master(1:400); 
            % Device 2 is pulses 350 to 800 (overlap of 50 pulses)
            true_shift = 0;
            true_scale = 1.0;
            t2 = t_master(350:800);
            
            [shift, scale] = ndi.time.fun.syncRandomTriggers(t1, t2);
            
            testCase.verifyFalse(isnan(scale), 'Should find the 10-second overlap');
            testCase.verifyEqual(scale, true_scale, 'RelTol', 1e-10);
        end

        function testNoOverlap(testCase)
            % Two completely different sets of random times
            t1 = cumsum(rand(100, 1));
            t2 = cumsum(rand(100, 1)) + 5000; % Distant in time and different intervals
            
            [shift, scale] = ndi.time.fun.syncRandomTriggers(t1, t2);
            
            testCase.verifyTrue(isnan(shift), 'Should return NaN for unrelated data');
            testCase.verifyTrue(isnan(scale), 'Should return NaN for unrelated data');
        end

    end
end