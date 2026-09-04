classdef NotInstalledTest < matlab.unittest.TestCase
    % NOTINSTALLEDTEST - Tests the guards that every step which shells out to
    % JRCLUST puts in front of itself.
    %
    % NDI can read and import a finished JRCLUST sort without JRCLUST, but it
    % cannot write a parameter file, detect, sort, curate or view traces without
    % it. Each of those reports the installation problem rather than failing on an
    % undefined 'jrc'. These tests only run where JRCLUST is absent (the usual CI
    % case); where it is installed they are assumption-filtered out.

    properties
        WorkDir string = ""
        S
        P
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            info = ndi.fun.probe.import.jrclust.install();
            testCase.assumeFalse(info.ok, ...
                'JRCLUST is installed here, so the not-installed guards cannot be tested.');

            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));
            testCase.S = ndi.unittest.fun.probe.import.jrclust.MockSession( ...
                char(testCase.WorkDir));
            testCase.P = ndi.unittest.fun.probe.import.jrclust.MockProbe();
        end
    end

    methods (Test)
        function testInstallReportsWhatIsMissing(testCase)
            info = ndi.fun.probe.import.jrclust.install();

            testCase.verifyFalse(info.ok);
            testCase.verifyFalse(info.installed);
            testCase.verifyNotEmpty(info.summary);
            % the summary tells the user where to get it and which branch to use
            testCase.verifySubstring(info.summary,'github.com/VH-Lab/JRCLUST');
            testCase.verifySubstring(info.summary,'ndi_import');
        end

        function testRequirePrmReportsTheInstallation(testCase)
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.requireprm( ...
                testCase.S, testCase.P), ...
                'ndi:fun:probe:import:jrclust:notInstalled');
        end

        function testExportNeedsJRCLUST(testCase)
            testCase.verifyError(@() ndi.fun.probe.export.jrclust( ...
                testCase.S, testCase.P), ...
                'ndi:fun:probe:export:jrclust:notInstalled');
        end

        function testRunNeedsJRCLUST(testCase)
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.run( ...
                testCase.S, testCase.P), ...
                'ndi:fun:probe:import:jrclust:notInstalled');
        end

        function testCurateNeedsJRCLUST(testCase)
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.curate( ...
                testCase.S, testCase.P), ...
                'ndi:fun:probe:import:jrclust:notInstalled');
        end

        function testTracesNeedsJRCLUST(testCase)
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.traces( ...
                testCase.S, testCase.P), ...
                'ndi:fun:probe:import:jrclust:notInstalled');
        end

        function testEditingParametersNeedsAParameterFile(testCase)
            % editParameters does not need JRCLUST - it opens the file in the
            % MATLAB editor - but the file has to exist
            testCase.verifyError(@() ndi.fun.probe.import.jrclust.editParameters( ...
                testCase.S, testCase.P), ...
                'ndi:fun:probe:import:jrclust:noPrmFile');
        end
    end
end
