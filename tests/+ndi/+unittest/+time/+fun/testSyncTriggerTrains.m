classdef testSyncTriggerTrains < matlab.unittest.TestCase
    % TESTSYNCTRIGGERTRAINS - Professional unit tests for NDI pulse synchronization
    %
    % This class validates the robust synchronization of digital pulse trains,
    % specifically handling jitter, clock drift, and dropped pulses.
    %
    % Run with: 
    %   results = runtests('ndi.unittest.time.fun.testSyncTriggerTrains')

    methods (Test)
        
        function testIdentityWithJitter(testCase)
            % TEST 1: Identity mapping with minor jitter
            % Validates that hashing works when the signal isn't perfectly periodic.
            t_base = (0:10:500)';
            jitter = 0.05 * randn(size(t_base));
            true_shift = 50;
            t1 = t_base + jitter;
            t2 = t_base + jitter + true_shift;
            
            [s, m] = ndi.time.fun.syncTriggerTrains(t1, t2);
            
            testCase.verifyEqual(m, 1, 'RelTol', 1e-7);
            testCase.verifyEqual(s, true_shift, 'AbsTol', 1e-3);
        end

        function testJitterAndDrift(testCase)
            % TEST 2: High-precision recovery of drift (200ppm) and noise
            % Ensures the seed search and validation handle "stretched" intervals.
            true_s = 12.345;
            true_m = 1.0002;
            % Use non-uniform intervals to provide a unique hash fingerprint
            t1 = cumsum(1 + 0.5 * rand(200,1));
            t2 = true_m * t1 + true_s + 0.0002 * randn(size(t1));
            
            [s, m] = ndi.time.fun.syncTriggerTrains(t1, t2);
            
            testCase.verifyFalse(isnan(s), 'Synchronization failed to find a match (returned NaN).');
            testCase.verifyEqual(m, true_m, 'RelTol', 1e-4);
            testCase.verifyEqual(s, true_s, 'AbsTol', 0.05);
        end

        function testDevice1DroppedPulse(testCase)
            % TEST 3: The "Steve" Case - Device 1 is missing a pulse
            % Simulates a periodic signal where a single drop reveals the mapping.
            t1_periodic = [];
            for i = 0:40
                t1_periodic = [t1_periodic; i*30; i*30+5];
            end
            t1_periodic = t1_periodic + 0.01*randn(size(t1_periodic)); % Add jitter

            true_shift = 100;
            t2_full = t1_periodic + true_shift;
            t1_dropped = t1_periodic;
            t1_dropped(25) = []; % Simulate dropped pulse in T1

            [s, m] = ndi.time.fun.syncTriggerTrains(t1_dropped, t2_full);
            
            testCase.verifyFalse(isnan(s), 'Failed when Device 1 dropped a pulse.');
            testCase.verifyEqual(s, true_shift, 'AbsTol', 0.05);
            testCase.verifyEqual(m, 1.0, 'RelTol', 1e-5);
        end

        function testDevice2DroppedPulse(testCase)
            % TEST 4: Device 2 is missing a pulse
            % Ensures inversion logic handles drops in the prober device.
            t1_periodic = [];
            for i = 0:40
                t1_periodic = [t1_periodic; i*30; i*30+5]; 
            end
            t1_periodic = t1_periodic + 0.01*randn(size(t1_periodic));
            
            true_shift = -50;
            t2_dropped = t1_periodic + true_shift;
            t2_dropped(10) = []; % Simulate dropped pulse in T2
            
            [s, m] = ndi.time.fun.syncTriggerTrains(t1_periodic, t2_dropped);
            
            testCase.verifyFalse(isnan(s), 'Failed when Device 2 dropped a pulse.');
            testCase.verifyEqual(s, true_shift, 'AbsTol', 0.05);
            testCase.verifyEqual(m, 1.0, 'RelTol', 1e-5);
        end

        function testAmbiguityBailout(testCase)
            % TEST 5: Ambiguity Detection (The Periodic Trap)
            % Ensures the function errors if data is perfectly regular (no unique fit).
            t_p1 = (0:50)'; 
            t_p2 = (5:55)'; 
            
            testCase.verifyError(@() ndi.time.fun.syncTriggerTrains(t_p1, t_p2), ...
                'ndi:time:sync:ambiguous');
        end

        function testLargeDatasetPerformance(testCase)
            % TEST 6: Performance check with 1000 pulses
            % Ensures the exhaustive validation loop remains performant.
            n = 1000;
            t1 = cumsum(0.2 + 0.8 * rand(n,1));
            t2 = 1.0001 * t1 + 5.0 + 0.0001*randn(n,1);
            
            tic;
            [s, m] = ndi.time.fun.syncTriggerTrains(t1, t2);
            runtime = toc;
            
            testCase.verifyLessThan(runtime, 5.0, 'Sync took too long for 1000 pulses.');
            testCase.verifyFalse(isnan(s), 'Large dataset sync returned NaN.');
        end

    end
end