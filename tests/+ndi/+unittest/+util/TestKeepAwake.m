classdef TestKeepAwake < matlab.unittest.TestCase
    % TestKeepAwake - ndi.util.KeepAwake, with a fake helper process.
    %
    % Nothing here really keeps the computer awake: ndi.test.helper.FakeLauncher
    % records the helper that would have been started.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties
        launcher
    end

    methods (TestMethodSetup)
        function fake(testCase)
            testCase.launcher = ndi.test.helper.FakeLauncher.install(testCase);
        end
    end

    methods (Test)

        function testOneHelperWhileAnythingHoldsIt(testCase)
            k = ndi.util.KeepAwake.instance();
            testCase.verifyFalse(k.isOn());
            k.hold('a', 'job a');
            k.hold('b', 'job b');
            testCase.verifyTrue(k.isOn());
            testCase.verifyNumElements(testCase.launcher.processes, 1, ...
                'a second holder shares the helper');
            k.release('a');
            testCase.verifyTrue(k.isOn(), 'b still holds it');
            k.release('b');
            testCase.verifyFalse(k.isOn());
            testCase.verifyEqual(testCase.launcher.running(), 0, 'the helper is stopped');
        end

        function testHoldingTwiceIsOneHold(testCase)
            k = ndi.util.KeepAwake.instance();
            k.hold('a');
            k.hold('a');
            k.release('a');
            testCase.verifyFalse(k.isOn());
        end

        function testTheManualToggle(testCase)
            k = ndi.util.KeepAwake.instance();
            k.toggleManual();
            testCase.verifyTrue(k.manualOn());
            testCase.verifyTrue(k.isOn());
            testCase.verifySubstring(k.describe(), 'Keeping this computer awake');
            k.toggleManual();
            testCase.verifyFalse(k.isOn());
            testCase.verifySubstring(k.describe(), 'sleep as usual');
        end

        function testChangesAreAnnounced(testCase)
            k = ndi.util.KeepAwake.instance();
            n = 0;
            function count(~, ~)
                n = n + 1;
            end
            l = listener(k, 'Changed', @count); %#ok<NASGU> kept alive for the test
            k.hold('a');
            k.release('a');
            testCase.verifyEqual(n, 2);
        end

        function testAHelperThatStopsIsReported(testCase)
            k = ndi.util.KeepAwake.instance();
            k.hold('a');
            testCase.launcher.processes{1}.exitNow();
            testCase.verifyFalse(k.isOn());
            testCase.verifySubstring(k.describe(), 'Could not keep this computer awake');
            k.hold('b');
            testCase.verifyTrue(k.isOn(), 'the next hold starts it again');
        end

        function testTheHelperForEachComputer(testCase)
            mac = ndi.util.KeepAwake.commandFor('mac', 123);
            testCase.verifyEqual(mac, {'caffeinate', '-ims', '-w', '123'});

            linux = ndi.util.KeepAwake.commandFor('linux', 123);
            testCase.verifyEqual(linux{1}, 'systemd-inhibit');
            testCase.verifyTrue(any(strcmp(linux, '--what=idle:sleep')));
            testCase.verifyTrue(any(strcmp(linux, '--pid=123')), ...
                'it ends when MATLAB does');

            win = ndi.util.KeepAwake.commandFor('windows', 123);
            testCase.verifyEqual(win{1}, 'powershell');
            k = find(strcmp(win, '-EncodedCommand'));
            testCase.assertNotEmpty(k);
            script = native2unicode(matlab.net.base64decode(win{k + 1}), 'UTF-16LE');
            testCase.verifySubstring(script, 'SetThreadExecutionState([uint32]2147483649)');
            testCase.verifySubstring(script, 'Wait-Process -Id 123');
        end

        function testTheHelperIsTiedToThisMatlab(testCase)
            k = ndi.util.KeepAwake.instance();
            k.hold('a');
            args = testCase.launcher.processes{1}.args;
            testCase.verifyTrue(any(contains(args, sprintf('%d', ndi.job.Job.processId()))) || ...
                contains(native2unicode(matlab.net.base64decode(args{end}), 'UTF-16LE'), ...
                sprintf('%d', ndi.job.Job.processId())));
        end
    end
end
