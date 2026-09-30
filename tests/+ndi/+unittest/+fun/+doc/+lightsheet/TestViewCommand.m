classdef TestViewCommand < matlab.unittest.TestCase
    % TestViewCommand - the pure command builder ndi.gui.app.LightsheetZarrManager
    % calls to hand a pyramid to the napari viewer.
    %
    % viewCommand does not launch anything or touch the filesystem, so a
    % test can assert the exact command string without a display, without
    % Python, and without a session. Every branch of the flag surface is
    % exercised so a UI change that quietly drops --no-controls or
    % --reduction fails here rather than in a demo.

    properties (Constant)
        Launcher = '/usr/local/bin/napariViewLightsheet'
        Session  = '/tmp/session1'
        Pyramid  = '4126a1b2c3d4e5f6_a1b2c3d4e5f6a1b2'
    end

    methods (Test)

        function testMinimalCommand(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid);
            testCase.verifyEqual(cmd, ...
                sprintf('''%s'' ''%s'' --pyramid ''%s''', ...
                    testCase.Launcher, testCase.Session, testCase.Pyramid));
        end

        function testReductionFlag(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                'reduction', 'max');
            testCase.verifyTrue(contains(cmd, '--reduction ''max'''));
        end

        function testReductionMeanFlag(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                'reduction', 'mean');
            testCase.verifyTrue(contains(cmd, '--reduction ''mean'''));
        end

        function testChannelFlag(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                'channel', 2);
            testCase.verifyTrue(contains(cmd, '--channel 2'));
        end

        function testChannelDefaultIsOmitted(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid);
            testCase.verifyFalse(contains(cmd, '--channel'), ...
                'channel=-1 (default) must not be emitted.');
        end

        function testLevelFlag(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                'level', 0);
            testCase.verifyTrue(contains(cmd, '--level 0'));
        end

        function testLevelDefaultIsOmitted(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid);
            testCase.verifyFalse(contains(cmd, '--level'), ...
                'level=-1 (default) must not be emitted.');
        end

        function testNoControls(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                'controls', false);
            testCase.verifyTrue(contains(cmd, '--no-controls'));
        end

        function testControlsDefaultIsOn(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid);
            testCase.verifyFalse(contains(cmd, '--no-controls'), ...
                'controls=true (default) must not emit --no-controls.');
        end

        function testNameFlag(testCase)
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                'name', 'my layer');
            testCase.verifyTrue(contains(cmd, '--name'));
            testCase.verifyTrue(contains(cmd, 'my layer'), ...
                'the layer name must appear in the command.');
        end

        function testEmptyLauncherErrors(testCase)
            testCase.verifyError( ...
                @() ndi.fun.doc.lightsheet.viewCommand('', ...
                    testCase.Session, testCase.Pyramid), ...
                'NDI:lightsheet:viewCommand:noLauncher');
        end

        function testEmptySessionPathErrors(testCase)
            testCase.verifyError( ...
                @() ndi.fun.doc.lightsheet.viewCommand( ...
                    testCase.Launcher, '', testCase.Pyramid), ...
                'NDI:lightsheet:viewCommand:noSessionPath');
        end

        function testEmptyPyramidIDErrors(testCase)
            % viewCommand refuses to build a command without a pyramid id;
            % the viewer will not guess which pyramid to open on a session
            % that holds more than one.
            testCase.verifyError( ...
                @() ndi.fun.doc.lightsheet.viewCommand( ...
                    testCase.Launcher, testCase.Session, ''), ...
                'NDI:lightsheet:viewCommand:noPyramidID');
        end

        function testInvalidReductionErrors(testCase)
            testCase.verifyError( ...
                @() ndi.fun.doc.lightsheet.viewCommand( ...
                    testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                    'reduction', 'median'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testFullFlagSurface(testCase)
            % Every flag together; order matters for a shell command, and
            % downstream (napariViewLightsheet argparse) accepts the flags
            % in any order, so the assertion is on presence + values.
            cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                testCase.Launcher, testCase.Session, testCase.Pyramid, ...
                'reduction', 'max', 'channel', 1, 'level', 2, ...
                'controls', false, 'name', 'V1');
            testCase.verifyTrue(startsWith(cmd, ...
                sprintf('''%s'' ''%s'' --pyramid ''%s''', ...
                    testCase.Launcher, testCase.Session, testCase.Pyramid)), ...
                'launcher, session, --pyramid must lead the command.');
            testCase.verifyTrue(contains(cmd, '--reduction ''max'''));
            testCase.verifyTrue(contains(cmd, '--channel 1'));
            testCase.verifyTrue(contains(cmd, '--level 2'));
            testCase.verifyTrue(contains(cmd, '--no-controls'));
            testCase.verifyTrue(contains(cmd, '--name'));
            testCase.verifyTrue(contains(cmd, 'V1'));
        end
    end
end
