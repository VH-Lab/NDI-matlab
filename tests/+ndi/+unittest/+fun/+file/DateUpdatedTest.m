classdef DateUpdatedTest < matlab.unittest.TestCase
    % DATEUPDATEDTEST - tests for ndi.fun.file.dateUpdated

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
    end

    methods (Test)

        function testFileDateIsRecent(testCase)
            f = testCase.writeFile('a.txt');
            d = ndi.fun.file.dateUpdated(f);

            testCase.verifyClass(d, 'datetime');
            testCase.verifyTrue(isscalar(d));
            testCase.verifyFalse(isnat(d), 'A file just written has a modification date.');
            % dir() reports local time, as does datetime('now')
            testCase.verifyLessThan(abs(d - datetime('now')), minutes(5), ...
                'Modification date of a just-written file is not close to now.');
        end

        function testFolderDate(testCase)
            % dir() on a folder lists its contents, so dateUpdated has to pick
            % the '.' entry to describe the folder itself rather than a child.
            d = ndi.fun.file.dateUpdated(testCase.tempDir);

            testCase.verifyClass(d, 'datetime');
            testCase.verifyTrue(isscalar(d));
            testCase.verifyFalse(isnat(d));
            testCase.verifyLessThan(abs(d - datetime('now')), minutes(5));
        end

        function testFolderWithContentsUsesFolderItself(testCase)
            % A folder holding several files must still yield one date, not one
            % per entry.
            testCase.writeFile('one.txt');
            testCase.writeFile('two.txt');
            d = ndi.fun.file.dateUpdated(testCase.tempDir);
            testCase.verifyTrue(isscalar(d));
            testCase.verifyFalse(isnat(d));
        end

        function testTrailingSeparatorOnFolder(testCase)
            d1 = ndi.fun.file.dateUpdated(testCase.tempDir);
            d2 = ndi.fun.file.dateUpdated([testCase.tempDir filesep]);
            testCase.verifyEqual(d2, d1);
        end

        function testModificationDateAdvancesAfterRewrite(testCase)
            % Guard against reading a creation time rather than a modification
            % time. Skipped where the filesystem timestamp is too coarse to
            % resolve the two writes.
            f = testCase.writeFile('a.txt');
            first = ndi.fun.file.dateUpdated(f);

            pause(1.1);   % filesystem timestamps can have 1 s resolution
            fid = fopen(f, 'a');
            testCase.assertGreaterThan(fid, 0);
            fprintf(fid, ' more');
            fclose(fid);

            second = ndi.fun.file.dateUpdated(f);
            testCase.verifyGreaterThanOrEqual(second, first, ...
                'Modification date went backwards after a rewrite.');
        end

        function testAcceptsStringInput(testCase)
            f = testCase.writeFile('a.txt');
            testCase.verifyEqual(ndi.fun.file.dateUpdated(string(f)), ...
                ndi.fun.file.dateUpdated(f));
        end

        function testMissingPathWarnsAndReturnsNaT(testCase)
            missing = fullfile(testCase.tempDir, 'does_not_exist.txt');
            testCase.verifyWarning(@() ndi.fun.file.dateUpdated(missing), ...
                'ndi:fun:file:dateUpdated:pathNotFound');

            warnState = warning('off', 'ndi:fun:file:dateUpdated:pathNotFound');
            restoreWarn = onCleanup(@() warning(warnState)); %#ok<NASGU>
            d = ndi.fun.file.dateUpdated(missing);
            testCase.verifyClass(d, 'datetime');
            testCase.verifyTrue(isnat(d), 'A missing path must yield NaT.');
        end

    end
end
