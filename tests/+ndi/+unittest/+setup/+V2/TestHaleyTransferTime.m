classdef TestHaleyTransferTime < matlab.unittest.TestCase
%TESTHALEYTRANSFERTIME ndi.setup.conv.haley.transferTime over the real spec's
%transfer_protocol (decision #52): which video start stands for the transfer.

    properties
        Protocol
    end

    methods (TestClassSetup)
        function readSpec(testCase)
            specFile = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), ...
                'import_V2_spec.json');
            spec = jsondecode(fileread(specFile));
            testCase.Protocol = spec.transfer_protocol;
        end
    end

    methods (Test)
        function testLawnFirstUsesTheRecordingStart(testCase)
            b = datetime(2022, 3, 18, 10, 0, 0);
            [T, rule] = ndi.setup.conv.haley.transferTime(testCase.Protocol, ...
                'foragingConcentration', b, b - minutes(9), '2022-03-18_10-00-00_1');
            testCase.verifyEqual(T, b);
            testCase.verifyEqual(rule.contrast_video, 'before_worms');
            testCase.verifySubstring(rule.method, 'agar plug');
        end

        function testWormsFirstUsesTheLawnClip(testCase)
            b = datetime(2023, 1, 6, 10, 0, 0);
            [T, rule] = ndi.setup.conv.haley.transferTime(testCase.Protocol, ...
                'foragingMini', b, b - minutes(0.2), '2023-01-06_10-00-00_1');
            testCase.verifyEqual(T, b - minutes(0.2));
            testCase.verifyEqual(rule.used, 'lawn clip');
        end

        function testMatchingSwitchesByDate(testCase)
            b = datetime(2023, 3, 31, 10, 0, 0);
            [T, rule] = ndi.setup.conv.haley.transferTime(testCase.Protocol, ...
                'foragingMatching', b, b - minutes(6), '2023-03-31_10-00-00_1');
            testCase.verifyEqual(T, b, 'days 2-3: lawn first');
            testCase.verifySubstring(rule.method, 'eyelash');
            b = datetime(2023, 5, 18, 10, 0, 0);
            T = ndi.setup.conv.haley.transferTime(testCase.Protocol, ...
                'foragingMatching', b, b - minutes(1), '2023-05-18_10-00-00_1');
            testCase.verifyEqual(T, b - minutes(1), 'days 4-5: worms first');
            b = datetime(2023, 2, 24, 10, 0, 0);
            T = ndi.setup.conv.haley.transferTime(testCase.Protocol, ...
                'foragingMatching', b, b - minutes(0.6), '2023-02-24_10-00-00_1');
            testCase.verifyEqual(T, b - minutes(0.6), 'day 1: worms first');
        end

        function testTheNamedExceptionIsWormsFirst(testCase)
            b = datetime(2023, 4, 4, 16, 11, 30);
            [T, rule] = ndi.setup.conv.haley.transferTime(testCase.Protocol, ...
                'foragingMatching', b, b - minutes(1.4), '2023-04-04_16-10-14_2');
            testCase.verifyEqual(T, b - minutes(1.4));
            testCase.verifyEqual(rule.source, 'exception');
            % Concentration, 2022-09-02 08:48:41: the contrast video was taken
            % late, once the worms were on (both cameras)
            b = datetime(2022, 9, 2, 8, 48, 41);
            for cam = ["_1", "_2"]
                [T, rule] = ndi.setup.conv.haley.transferTime(testCase.Protocol, ...
                    'foragingConcentration', b, b - seconds(33), char("2022-09-02_08-48-41" + cam));
                testCase.verifyEqual(T, b - seconds(33));
                testCase.verifyEqual(rule.source, 'exception');
            end
        end

        function testAFarOrLateLawnClipIsNotUsed(testCase)
            b = datetime(2023, 11, 3, 10, 0, 0);
            T = ndi.setup.conv.haley.transferTime(testCase.Protocol, 'foragingMutants', ...
                b, b - hours(2), 'x');
            testCase.verifyEqual(T, b, 'more than an hour before: the clip is not this transfer');
            T = ndi.setup.conv.haley.transferTime(testCase.Protocol, 'foragingMutants', ...
                b, b + minutes(1), 'x');
            testCase.verifyEqual(T, b, 'after the recording started: not the transfer either');
        end

        function testNoVideoNoTime(testCase)
            T = ndi.setup.conv.haley.transferTime(testCase.Protocol, 'foragingMini', NaT, NaT, '');
            testCase.verifyTrue(isnat(T));
        end
    end
end
