classdef daqsystemstringTest < matlab.unittest.TestCase
    methods (Test)
        function testBasicParsing(testCase)
            % Verify basic device string parsing (existing functionality)
            ds = ndi.daq.daqsystemstring('mydevice:ai1-5,13,18');
            [devicename, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(devicename, 'mydevice');
            testCase.verifyEqual(channel, [1 2 3 4 5 13 18]);
            testCase.verifyEqual(channeltype, repmat({'ai'}, 1, 7));
        end

        function testMultipleChannelTypes(testCase)
            ds = ndi.daq.daqsystemstring('dev:ai1-3;di4');
            [devicename, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(devicename, 'dev');
            testCase.verifyEqual(channel, [1 2 3 4]);
            testCase.verifyEqual(channeltype, {'ai','ai','ai','di'});
        end

        function testDigitalEventTypes(testCase)
            ds = ndi.daq.daqsystemstring('dev:dep1;den2');
            [~, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(channel, [1 2]);
            testCase.verifyEqual(channeltype, {'dep','den'});
        end

        function testAnalogEventBasic(testCase)
            % aep without threshold
            ds = ndi.daq.daqsystemstring('dev:aep1');
            [~, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(channel, 1);
            testCase.verifyEqual(channeltype, {'aep'});
        end

        function testAnalogEventWithThreshold(testCase)
            ds = ndi.daq.daqsystemstring('dev:aep1_t2.5');
            [~, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(channel, 1);
            testCase.verifyEqual(channeltype, {'aep_t2.5'});
        end

        function testAnalogEventMultipleChannelsWithThreshold(testCase)
            ds = ndi.daq.daqsystemstring('dev:aep1-3_t2.5');
            [~, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(channel, [1 2 3]);
            testCase.verifyEqual(channeltype, {'aep_t2.5','aep_t2.5','aep_t2.5'});
        end

        function testAnalogEventNegWithThreshold(testCase)
            ds = ndi.daq.daqsystemstring('dev:aen5_t0.1');
            [~, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(channel, 5);
            testCase.verifyEqual(channeltype, {'aen_t0.1'});
        end

        function testMixedAnalogEventAndRegular(testCase)
            ds = ndi.daq.daqsystemstring('dev:ai1-2;aep3_t2.5');
            [~, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(channel, [1 2 3]);
            testCase.verifyEqual(channeltype, {'ai','ai','aep_t2.5'});
        end

        function testDevicestringRoundtrip(testCase)
            % Parse and reconstruct, verify round-trip
            original = 'dev:ai1-3';
            ds = ndi.daq.daqsystemstring(original);
            testCase.verifyEqual(ds.devicestring(), original);
        end

        function testDevicestringRoundtripWithThreshold(testCase)
            original = 'dev:aep1-3_t2.5';
            ds = ndi.daq.daqsystemstring(original);
            testCase.verifyEqual(ds.devicestring(), original);
        end

        function testDevicestringRoundtripMixed(testCase)
            original = 'dev:ai1-2;aep3_t2.5';
            ds = ndi.daq.daqsystemstring(original);
            testCase.verifyEqual(ds.devicestring(), original);
        end

        function testParseAnalogEventChanneltype(testCase)
            [base, thresh] = ndi.daq.daqsystemstring.parse_analog_event_channeltype('aep_t2.5');
            testCase.verifyEqual(base, 'aep');
            testCase.verifyEqual(thresh, 2.5);
        end

        function testParseAnalogEventChanneltypeNoThreshold(testCase)
            [base, thresh] = ndi.daq.daqsystemstring.parse_analog_event_channeltype('aep');
            testCase.verifyEqual(base, 'aep');
            testCase.verifyEqual(thresh, 0);
        end

        function testParseAnalogEventChanneltypeNegative(testCase)
            [base, thresh] = ndi.daq.daqsystemstring.parse_analog_event_channeltype('aen_t0.3');
            testCase.verifyEqual(base, 'aen');
            testCase.verifyEqual(thresh, 0.3, 'AbsTol', 1e-15);
        end

        function testAnalogMarkWithThreshold(testCase)
            ds = ndi.daq.daqsystemstring('dev:aimp1_t1.0;aimn2_t0.5');
            [~, channeltype, channel] = ndi_daqsystemstring2channel(ds);
            testCase.verifyEqual(channel, [1 2]);
            testCase.verifyEqual(channeltype, {'aimp_t1.0','aimn_t0.5'});
        end
    end
end
