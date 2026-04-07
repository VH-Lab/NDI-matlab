classdef analogEventTest < matlab.unittest.TestCase
    methods (Test)
        function testIsAnalogEventType(testCase)
            % Verify the static helper correctly identifies analog event types
            [tf, base, thresh] = ndi.daq.reader.mfdaq.is_analog_event_type({'aep_t2.5'});
            testCase.verifyTrue(tf);
            testCase.verifyEqual(base, {'aep'});
            testCase.verifyEqual(thresh, 2.5);

            [tf, base, thresh] = ndi.daq.reader.mfdaq.is_analog_event_type({'aen'});
            testCase.verifyTrue(tf);
            testCase.verifyEqual(base, {'aen'});
            testCase.verifyEqual(thresh, 0);

            [tf, ~, ~] = ndi.daq.reader.mfdaq.is_analog_event_type({'ai'});
            testCase.verifyFalse(tf);

            [tf, ~, ~] = ndi.daq.reader.mfdaq.is_analog_event_type({'dep'});
            testCase.verifyFalse(tf);
        end

        function testRampUpwardCrossing(testCase)
            % A ramp from 0 to 5 over 10s should cross threshold 2.5 once (upward) near t=5
            reader = ndi.unittest.daq.reader.MockAnalogDAQReader();
            epochfiles = {'mock'};
            [timestamps, data] = reader.readevents_epochsamples({'aep_t2.5'}, 1, epochfiles, -Inf, Inf);
            testCase.verifyNumElements(timestamps, 1, 'Expected exactly one upward crossing');
            testCase.verifyEqual(data, 1, 'Data for upward crossing should be 1');
            testCase.verifyEqual(timestamps, 5.0, 'AbsTol', 0.002, 'Crossing should be near t=5.0');
        end

        function testRampNoDownwardCrossing(testCase)
            % A monotonically increasing ramp should have no downward crossings
            reader = ndi.unittest.daq.reader.MockAnalogDAQReader();
            epochfiles = {'mock'};
            [timestamps, ~] = reader.readevents_epochsamples({'aen_t2.5'}, 1, epochfiles, -Inf, Inf);
            testCase.verifyEmpty(timestamps, 'Monotonic ramp should have no downward crossings');
        end

        function testPulseUpwardCrossings(testCase)
            % Pulse signal: two pulses (t=1.0-1.1 and t=3.0-3.1) should produce two upward crossings
            reader = ndi.unittest.daq.reader.MockPulseAnalogDAQReader();
            epochfiles = {'mock'};
            [timestamps, data] = reader.readevents_epochsamples({'aep_t2.5'}, 1, epochfiles, -Inf, Inf);
            testCase.verifyNumElements(timestamps, 2, 'Expected two upward crossings');
            testCase.verifyEqual(data, [1; 1], 'All upward crossings should have data=1');
            testCase.verifyEqual(timestamps(1), 1.0, 'AbsTol', 0.002, 'First crossing near t=1.0');
            testCase.verifyEqual(timestamps(2), 3.0, 'AbsTol', 0.002, 'Second crossing near t=3.0');
        end

        function testPulseDownwardCrossings(testCase)
            % Two pulses should also produce two downward crossings
            reader = ndi.unittest.daq.reader.MockPulseAnalogDAQReader();
            epochfiles = {'mock'};
            [timestamps, data] = reader.readevents_epochsamples({'aen_t2.5'}, 1, epochfiles, -Inf, Inf);
            testCase.verifyNumElements(timestamps, 2, 'Expected two downward crossings');
            testCase.verifyEqual(data, [-1; -1], 'All downward crossings should have data=-1');
            testCase.verifyEqual(timestamps(1), 1.1, 'AbsTol', 0.002, 'First down crossing near t=1.1');
            testCase.verifyEqual(timestamps(2), 3.1, 'AbsTol', 0.002, 'Second down crossing near t=3.1');
        end

        function testPulseMarkPositive(testCase)
            % aimp should find both up and down crossings for each pulse
            reader = ndi.unittest.daq.reader.MockPulseAnalogDAQReader();
            epochfiles = {'mock'};
            [timestamps, data] = reader.readevents_epochsamples({'aimp_t2.5'}, 1, epochfiles, -Inf, Inf);
            % 2 pulses = 2 up + 2 down = 4 events total
            testCase.verifyNumElements(timestamps, 4, 'Expected 4 transitions for 2 pulses with aimp');
            % Events should be sorted by time
            testCase.verifyTrue(issorted(timestamps), 'Timestamps should be sorted');
            % Up crossings have data=1, down crossings have data=-1
            testCase.verifyEqual(sum(data == 1), 2, 'Should have 2 positive transitions');
            testCase.verifyEqual(sum(data == -1), 2, 'Should have 2 negative transitions');
        end

        function testDefaultThresholdIsZero(testCase)
            % aep without _t suffix should use threshold 0
            % The pulse signal baseline is exactly 0, which is >= 0, so it is
            % never "below" threshold. No below-to-above crossings should occur.
            reader = ndi.unittest.daq.reader.MockPulseAnalogDAQReader();
            epochfiles = {'mock'};
            [timestamps, ~] = reader.readevents_epochsamples({'aep'}, 1, epochfiles, -Inf, Inf);
            testCase.verifyEmpty(timestamps, 'Signal never goes below 0, so no upward crossings at threshold 0');
            % Verify that the threshold is actually parsed as 0
            [~, thresh] = ndi.daq.daqsystemstring.parse_analog_event_channeltype('aep');
            testCase.verifyEqual(thresh, 0, 'Default threshold should be 0');
        end

        function testHighThresholdNoCrossings(testCase)
            % Threshold above max signal value should yield no events
            reader = ndi.unittest.daq.reader.MockPulseAnalogDAQReader();
            epochfiles = {'mock'};
            [timestamps, ~] = reader.readevents_epochsamples({'aep_t10.0'}, 1, epochfiles, -Inf, Inf);
            testCase.verifyEmpty(timestamps, 'Threshold above signal max should yield no events');
        end

        function testMfdaqPrefix(testCase)
            % Verify MFDAQ_PREFIX handles analog event types
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('aep'), 'aep');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('aen'), 'aen');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('aimp'), 'aimp');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('aimn'), 'aimn');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('analog_in_event_pos'), 'aep');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('analog_in_event_neg'), 'aen');
        end

        function testMfdaqPrefixWithThreshold(testCase)
            % Verify MFDAQ_PREFIX preserves threshold suffix
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('aep_t2.5'), 'aep_t2.5');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_prefix('aen_t0.1'), 'aen_t0.1');
        end

        function testMfdaqType(testCase)
            % Verify MFDAQ_TYPE handles analog event types
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_type('aep'), 'analog_in_event_pos');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_type('aen'), 'analog_in_event_neg');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_type('aep_t2.5'), 'analog_in_event_pos');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_type('aimp'), 'analog_in_mark_pos');
            testCase.verifyEqual(ndi.daq.system.mfdaq.mfdaq_type('aimn'), 'analog_in_mark_neg');
        end
    end
end
