classdef ElementDirectoryTest < matlab.unittest.TestCase
    % ELEMENTDIRECTORYTEST - tests for the platform-independent element folder names
    %
    % Covers ndi.fun.file.pathSafeName, ndi.fun.file.elementDirectoryName and
    % ndi.fun.file.elementDirectory, including the fallback to the legacy
    % '|'-separated folder names written by earlier versions of NDI.

    properties
        rootDir  % temporary parent directory for the folder-resolution tests
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            testCase.rootDir = tempname;   % unique, does not yet exist
            mkdir(testCase.rootDir);
            testCase.addTeardown(@() rmdir(testCase.rootDir, 's'));
        end
    end

    methods (Test)

        function testPathSafeNameReplacesIllegalCharacters(testCase)
            % Every character Windows forbids must be gone, and the pipe in
            % particular must become the '-' separator.
            testCase.verifyEqual(ndi.fun.file.pathSafeName('ctx_|_1'), 'ctx_-_1');
            testCase.verifyEqual(ndi.fun.file.pathSafeName('ctx | 1'), 'ctx_-_1');

            illegal = '<>:"/\|?*';
            safe = ndi.fun.file.pathSafeName(['a' illegal 'b']);
            for i = 1:numel(illegal)
                testCase.verifyFalse(any(safe == illegal(i)), ...
                    sprintf('Character ''%s'' survived pathSafeName.', illegal(i)));
            end
            testCase.verifyEqual(safe, ['a' repmat('-',1,numel(illegal)) 'b']);
        end

        function testPathSafeNameKeepsPortableCharacters(testCase)
            portable = 'AZaz09._-';
            testCase.verifyEqual(ndi.fun.file.pathSafeName(portable), portable);
        end

        function testPathSafeNameWhitespaceAndControlCharacters(testCase)
            testCase.verifyEqual(ndi.fun.file.pathSafeName('my probe'), 'my_probe');
            testCase.verifyEqual(ndi.fun.file.pathSafeName(['a' char(9) 'b']), 'a_b');
            testCase.verifyEqual(ndi.fun.file.pathSafeName(['a' char(10) 'b']), 'a_b');
        end

        function testPathSafeNameEdgeCases(testCase)
            % Windows strips trailing dots; a reserved device name is unusable
            % even with an extension; an empty result must still be a name.
            testCase.verifyEqual(ndi.fun.file.pathSafeName('probe...'), 'probe');
            testCase.verifyEqual(ndi.fun.file.pathSafeName('CON'), '_CON');
            testCase.verifyEqual(ndi.fun.file.pathSafeName('nul.txt'), '_nul.txt');
            testCase.verifyEqual(ndi.fun.file.pathSafeName('COM3'), '_COM3');
            testCase.verifyEqual(ndi.fun.file.pathSafeName('CONSOLE'), 'CONSOLE'); % not reserved
            testCase.verifyEqual(ndi.fun.file.pathSafeName('...'), 'x');
            testCase.verifyEqual(ndi.fun.file.pathSafeName(''), 'x');
        end

        function testPathSafeNameAcceptsString(testCase)
            testCase.verifyEqual(ndi.fun.file.pathSafeName("ctx | 1"), 'ctx_-_1');
        end

        function testElementDirectoryNameFromObjectAndString(testCase)
            probe = ndi.unittest.fun.probe.MockProbe('ctx | 1');

            [dirName, legacyName] = ndi.fun.file.elementDirectoryName(probe);
            testCase.verifyEqual(dirName, 'ctx_-_1');
            testCase.verifyEqual(legacyName, 'ctx_|_1');

            % the same, given the element string directly
            [dirName2, legacyName2] = ndi.fun.file.elementDirectoryName('ctx | 1');
            testCase.verifyEqual(dirName2, dirName);
            testCase.verifyEqual(legacyName2, legacyName);
        end

        function testElementDirectoryNameUnchangedWhenAlreadySafe(testCase)
            [dirName, legacyName] = ndi.fun.file.elementDirectoryName('mock_probe');
            testCase.verifyEqual(dirName, 'mock_probe');
            testCase.verifyEqual(legacyName, 'mock_probe');
        end

        function testElementDirectoryUsesNewNameWhenNothingExists(testCase)
            [p, name, isLegacy] = ndi.fun.file.elementDirectory(testCase.rootDir, 'ctx | 1');
            testCase.verifyEqual(name, 'ctx_-_1');
            testCase.verifyEqual(p, fullfile(testCase.rootDir, 'ctx_-_1'));
            testCase.verifyFalse(isLegacy);
        end

        function testElementDirectoryUsesNewNameWhenItExists(testCase)
            mkdir(fullfile(testCase.rootDir, 'ctx_-_1'));
            [p, name, isLegacy] = ndi.fun.file.elementDirectory(testCase.rootDir, 'ctx | 1');
            testCase.verifyEqual(name, 'ctx_-_1');
            testCase.verifyEqual(p, fullfile(testCase.rootDir, 'ctx_-_1'));
            testCase.verifyFalse(isLegacy);
        end

        function testElementDirectoryFallsBackToLegacyFolder(testCase)
            % Data written by an older NDI must still be found. Skipped on
            % Windows, where the legacy folder cannot be created at all --
            % which is the reason for this change.
            testCase.assumeFalse(ispc, ...
                'Legacy ''|'' folder names cannot be created on Windows.');

            legacyDir = fullfile(testCase.rootDir, 'ctx_|_1');
            mkdir(legacyDir);

            [p, name, isLegacy] = ndi.fun.file.elementDirectory(testCase.rootDir, 'ctx | 1');
            testCase.verifyEqual(name, 'ctx_|_1');
            testCase.verifyEqual(p, legacyDir);
            testCase.verifyTrue(isLegacy);
        end

        function testElementDirectoryPrefersNewFolderOverLegacy(testCase)
            testCase.assumeFalse(ispc, ...
                'Legacy ''|'' folder names cannot be created on Windows.');

            mkdir(fullfile(testCase.rootDir, 'ctx_|_1'));
            mkdir(fullfile(testCase.rootDir, 'ctx_-_1'));

            [p, name, isLegacy] = ndi.fun.file.elementDirectory(testCase.rootDir, 'ctx | 1');
            testCase.verifyEqual(name, 'ctx_-_1');
            testCase.verifyEqual(p, fullfile(testCase.rootDir, 'ctx_-_1'));
            testCase.verifyFalse(isLegacy);
        end

        function testElementDirectoryAcceptsElementObject(testCase)
            % Every production call site passes a probe/element object rather than
            % the element string, so exercise that dispatch directly.
            probe = ndi.unittest.fun.probe.MockProbe('ctx | 1');

            [p, name, isLegacy] = ndi.fun.file.elementDirectory(testCase.rootDir, probe);
            testCase.verifyEqual(name, 'ctx_-_1');
            testCase.verifyEqual(p, fullfile(testCase.rootDir, 'ctx_-_1'));
            testCase.verifyFalse(isLegacy);
        end

        function testElementDirectoryObjectFallsBackToLegacyFolder(testCase)
            % The legacy fallback must work for an object argument too, since
            % that is how the importers and the export GUI call it.
            testCase.assumeFalse(ispc, ...
                'Legacy ''|'' folder names cannot be created on Windows.');

            probe = ndi.unittest.fun.probe.MockProbe('ctx | 1');
            legacyDir = fullfile(testCase.rootDir, 'ctx_|_1');
            mkdir(legacyDir);

            [p, name, isLegacy] = ndi.fun.file.elementDirectory(testCase.rootDir, probe);
            testCase.verifyEqual(name, 'ctx_|_1');
            testCase.verifyEqual(p, legacyDir);
            testCase.verifyTrue(isLegacy);
        end

        function testElementDirectoryAcceptsStringParentDir(testCase)
            % parentDir is validated with mustBeTextScalar, so a string scalar
            % must work as well as a char row vector.
            [p, name] = ndi.fun.file.elementDirectory(string(testCase.rootDir), 'ctx | 1');
            testCase.verifyEqual(name, 'ctx_-_1');
            testCase.verifyEqual(p, fullfile(testCase.rootDir, 'ctx_-_1'));
        end

        function testElementDirectoryNameAcceptsString(testCase)
            [dirName, legacyName] = ndi.fun.file.elementDirectoryName("ctx | 1");
            testCase.verifyEqual(dirName, 'ctx_-_1');
            testCase.verifyEqual(legacyName, 'ctx_|_1');
        end

        function testElementDirectoryNoLegacySearchWhenNameIsUnchanged(testCase)
            % A name that needs no sanitizing has no legacy alternative to find.
            [p, name, isLegacy] = ndi.fun.file.elementDirectory(testCase.rootDir, 'mock_probe');
            testCase.verifyEqual(name, 'mock_probe');
            testCase.verifyEqual(p, fullfile(testCase.rootDir, 'mock_probe'));
            testCase.verifyFalse(isLegacy);
        end

        function testExportWritesToPlatformSafeDirectory(testCase)
            % End to end: exporting a probe whose elementstring contains a '|'
            % must produce a folder that is legal on every platform.
            mockSession = ndi.unittest.fun.probe.MockSession('ctx | 1');

            binaryPath = fullfile(mockSession.path, 'kilosort');
            if isfolder(binaryPath)
                rmdir(binaryPath, 's');
            end
            testCase.addTeardown(@() i_rmIfPresent(binaryPath));

            ndi.fun.probe.export.all_binary(mockSession, 'verbose', 0, ...
                'binary_dir', 'kilosort');

            expectedDir = fullfile(binaryPath, 'ctx_-_1');
            testCase.verifyTrue(isfolder(expectedDir), ...
                'Export did not create the platform-independent probe directory.');
            testCase.verifyTrue(isfile(fullfile(expectedDir, 'kilosort.bin')), ...
                'Binary file not created in the expected directory.');
            testCase.verifyFalse(isfolder(fullfile(binaryPath, 'ctx_|_1')), ...
                'Export still created a directory containing ''|''.');
        end

    end
end

function i_rmIfPresent(d)
    if isfolder(d)
        rmdir(d, 's');
    end
end
