classdef DateCreatedTest < matlab.unittest.TestCase
    % DATECREATEDTEST - tests for ndi.fun.file.dateCreated
    %
    % dateCreated shells out to a native tool ('dir /T:C' on Windows, 'stat' on
    % macOS and Linux) and parses its text, so what it can return depends on the
    % platform: not every filesystem records a birth time at all. The tests below
    % separate the parts that must hold everywhere (class, scalar, NaT for a
    % missing file, never throwing) from the part that can only be checked where
    % the operating system actually reports a creation time.

    properties
        tempDir
    end

    methods (TestMethodSetup)
        function makeTempDir(testCase)
            testCase.tempDir = tempname;   % unique, does not yet exist
            mkdir(testCase.tempDir);
            testCase.addTeardown(@() rmdir(testCase.tempDir, 's'));
        end
    end

    methods (Access = private)
        function fileName = writeFile(testCase, name)
            fileName = fullfile(testCase.tempDir, name);
            fid = fopen(fileName, 'w');
            testCase.assertGreaterThan(fid, 0, ['Could not open ' fileName ' for writing.']);
            fprintf(fid, 'contents');
            fclose(fid);
        end

        function tf = osReportsBirthTime(~, fileName)
            % Ask the operating system directly, in epoch seconds, whether it
            % has a birth time for this file. GNU stat prints 0 (and BSD stat
            % prints the mtime) when it does not know one.
            if ispc
                tf = true;   % NTFS always records a creation time
                return;
            end
            if ismac
                [st, out] = system(sprintf('stat -f %%B "%s"', fileName));
            else
                [st, out] = system(sprintf('stat -c %%W "%s"', fileName));
            end
            value = str2double(strtrim(out));
            tf = (st == 0) && ~isnan(value) && value > 0;
        end
    end

    methods (Test)

        function testReturnsScalarDatetimeForExistingFile(testCase)
            f = testCase.writeFile('a.txt');
            d = ndi.fun.file.dateCreated(f);
            testCase.verifyClass(d, 'datetime');
            testCase.verifyTrue(isscalar(d));
        end

        function testRunsCleanlyForExistingFile(testCase)
            % The documented contract is NaT, not an error, when the creation
            % date cannot be determined -- callers such as
            % ndi.setup.conv.babu.import feed the result straight into
            % convertTo(...,'datenum'), where NaT becomes NaN.
            f = testCase.writeFile('a.txt');
            testCase.verifyWarningFree(@() ndi.fun.file.dateCreated(f));
        end

        function testReturnsDateWhenTheFilesystemHasOne(testCase)
            % If the operating system itself reports a birth time, dateCreated
            % must return it. A NaT here means its text parsing is broken on
            % this platform, which is the failure mode the try/catch would
            % otherwise hide.
            f = testCase.writeFile('a.txt');
            testCase.assumeTrue(testCase.osReportsBirthTime(f), ...
                'This filesystem does not record a file creation (birth) time.');

            d = ndi.fun.file.dateCreated(f);
            testCase.verifyFalse(isnat(d), ...
                ['The filesystem reports a creation time for this file but ' ...
                 'ndi.fun.file.dateCreated returned NaT, so its output parsing failed.']);
            testCase.verifyLessThan(abs(d - datetime('now')), minutes(5), ...
                'Creation date of a just-written file is not close to now.');
        end

        function testMissingFileReturnsNaT(testCase)
            missing = fullfile(testCase.tempDir, 'does_not_exist.txt');
            d = ndi.fun.file.dateCreated(missing);
            testCase.verifyClass(d, 'datetime');
            testCase.verifyTrue(isnat(d), 'A missing file must yield NaT.');
        end

        function testAcceptsStringInput(testCase)
            f = testCase.writeFile('a.txt');
            d = ndi.fun.file.dateCreated(string(f));
            testCase.verifyClass(d, 'datetime');
            testCase.verifyTrue(isscalar(d));
        end

        function testPathWithSpaces(testCase)
            % The path is quoted inside the shell command.
            f = testCase.writeFile('name with spaces.txt');
            d = ndi.fun.file.dateCreated(f);
            testCase.verifyClass(d, 'datetime');
            testCase.verifyTrue(isscalar(d));
            if testCase.osReportsBirthTime(f)
                testCase.verifyFalse(isnat(d), ...
                    'A path containing spaces was not passed to the shell intact.');
            end
        end

    end
end
