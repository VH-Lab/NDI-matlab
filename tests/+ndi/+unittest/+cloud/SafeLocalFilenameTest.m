classdef SafeLocalFilenameTest < matlab.unittest.TestCase
    % SAFELOCALFILENAMETEST - regression tests for the download path-traversal guard
    %
    % Guards ndi.cloud.download.internal.safeLocalFilename, used by
    % downloadDatasetFiles to keep a server-supplied file uid from writing
    % outside the target folder.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testPassesThroughNormalUid(testCase)
            [name, isSafe] = ndi.cloud.download.internal.safeLocalFilename(...
                "668b0539f13096e04f1feccd");
            testCase.verifyTrue(isSafe);
            testCase.verifyEqual(name, '668b0539f13096e04f1feccd');
        end

        function testStripsDirectoryTraversal(testCase)
            [name, isSafe] = ndi.cloud.download.internal.safeLocalFilename(...
                "../../../../.matlab/R2024b/startup.m");
            testCase.verifyTrue(isSafe);
            testCase.verifyEqual(name, 'startup.m');
        end

        function testStripsWindowsSeparators(testCase)
            [name, isSafe] = ndi.cloud.download.internal.safeLocalFilename(...
                "..\\..\\evil.m");
            testCase.verifyTrue(isSafe);
            testCase.verifyEqual(name, 'evil.m');
        end

        function testRejectsDotDot(testCase)
            [name, isSafe] = ndi.cloud.download.internal.safeLocalFilename("..");
            testCase.verifyFalse(isSafe);
            testCase.verifyEqual(name, '');
        end

        function testRejectsTrailingSeparator(testCase)
            [name, isSafe] = ndi.cloud.download.internal.safeLocalFilename("foo/");
            testCase.verifyFalse(isSafe);
            testCase.verifyEqual(name, '');
        end

        function testContainmentAfterJoin(testCase)
            % The joined path for a stripped filename stays inside targetFolder.
            targetFolder = tempname();
            [name, isSafe] = ndi.cloud.download.internal.safeLocalFilename(...
                "../../etc/passwd");
            testCase.verifyTrue(isSafe);
            joined = fullfile(fullfile(targetFolder, name));
            testCase.verifyTrue(startsWith(joined, fullfile(targetFolder)));
        end

    end

end
