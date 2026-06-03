classdef structArrayFileTest < matlab.unittest.TestCase
    % STRUCTARRAYFILETEST - Unit tests for ndi.util.saveStructArray / loadStructArray
    %
    % Description:
    %   Tests that ndi.util.saveStructArray and ndi.util.loadStructArray round-trip
    %   struct arrays through a tab-delimited text file, including the tricky case
    %   where string fields contain spaces (which can confuse delimiter
    %   auto-detection if explicit tab delimiters are not used).
    %

    properties
        testDir
    end

    methods (TestMethodSetup)
        function createTestDir(testCase)
            testCase.testDir = tempname;
            mkdir(testCase.testDir);
        end
    end

    methods (TestMethodTeardown)
        function removeTestDir(testCase)
            if exist(testCase.testDir, 'dir')
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods (Test)

        function testNumericRoundTrip(testCase)
            % A struct array with numeric scalar fields round-trips.
            s = struct('a', {1; 2; 3}, 'b', {10.5; 20.5; 30.5});
            f = fullfile(testCase.testDir, 'numeric.txt');
            ndi.util.saveStructArray(f, s);
            out = ndi.util.loadStructArray(f);

            testCase.verifyEqual(numel(out), 3, 'Should read back 3 rows.');
            testCase.verifyEqual([out.a], [1 2 3], 'Numeric field a should round-trip.');
            testCase.verifyEqual([out.b], [10.5 20.5 30.5], 'Numeric field b should round-trip.');
        end

        function testStringWithSpaces(testCase)
            % The key case: a text field containing spaces must round-trip intact,
            % which requires explicit tab delimiters on both write and read.
            s = struct('name', {'probe ctx 1'; 'probe lgn 2'}, 'count', {100; 250});
            f = fullfile(testCase.testDir, 'spaces.txt');
            ndi.util.saveStructArray(f, s);
            out = ndi.util.loadStructArray(f);

            testCase.verifyEqual(numel(out), 2, 'Should read back 2 rows.');
            testCase.verifyEqual(out(1).name, 'probe ctx 1', ...
                'A string with spaces must not be split across columns.');
            testCase.verifyEqual(out(2).name, 'probe lgn 2', ...
                'A string with spaces must not be split across columns.');
            testCase.verifyEqual([out.count], [100 250], ...
                'The numeric column following a spaced string must still be correct.');
        end

        function testTextReturnedAsChar(testCase)
            % Text columns should be returned as char vectors, not strings or cells.
            s = struct('label', {'alpha'; 'beta'}, 'v', {1; 2});
            f = fullfile(testCase.testDir, 'char.txt');
            ndi.util.saveStructArray(f, s);
            out = ndi.util.loadStructArray(f);

            testCase.verifyTrue(ischar(out(1).label), ...
                'Text values should be returned as char arrays.');
        end

        function testSingleElement(testCase)
            % A single-element struct array round-trips to one row.
            s = struct('x', 42, 'tag', 'hello world');
            f = fullfile(testCase.testDir, 'single.txt');
            ndi.util.saveStructArray(f, s);
            out = ndi.util.loadStructArray(f);

            testCase.verifyEqual(numel(out), 1, 'Should read back a single row.');
            testCase.verifyEqual(out.x, 42, 'Scalar numeric should round-trip.');
            testCase.verifyEqual(out.tag, 'hello world', 'Scalar text should round-trip.');
        end

        function testExplicitFieldsNoHeader(testCase)
            % When FIELDS are supplied, the file is read without a header row.
            % Build a headerless tab-delimited file by hand.
            f = fullfile(testCase.testDir, 'noheader.txt');
            fid = fopen(f, 'w');
            fprintf(fid, '%d\t%s\n', 1, 'first item');
            fprintf(fid, '%d\t%s\n', 2, 'second item');
            fclose(fid);

            out = ndi.util.loadStructArray(f, {'idx','desc'});
            testCase.verifyEqual(numel(out), 2, 'Should read 2 rows without a header.');
            testCase.verifyEqual([out.idx], [1 2], 'idx column should map correctly.');
            testCase.verifyEqual(out(1).desc, 'first item', ...
                'desc column with spaces should map correctly.');
        end

        function testFieldNamesPreserved(testCase)
            % The field names of the result should match the struct field names.
            s = struct('alpha', {1;2}, 'beta', {3;4}, 'gamma', {'x';'y'});
            f = fullfile(testCase.testDir, 'names.txt');
            ndi.util.saveStructArray(f, s);
            out = ndi.util.loadStructArray(f);

            testCase.verifyEqual(sort(fieldnames(out)), sort({'alpha';'beta';'gamma'}), ...
                'Field names should be preserved through the round-trip.');
        end

        function testEmptyStructErrors(testCase)
            % Saving an empty struct array should error.
            s = struct('a', {}, 'b', {});
            f = fullfile(testCase.testDir, 'empty.txt');
            testCase.verifyError(@() ndi.util.saveStructArray(f, s), ...
                'ndi:util:saveStructArray:emptyStruct', ...
                'An empty struct array should raise the emptyStruct error.');
        end

        function testMissingFileErrors(testCase)
            % Loading a nonexistent file should error.
            f = fullfile(testCase.testDir, 'doesnotexist.txt');
            testCase.verifyError(@() ndi.util.loadStructArray(f), ...
                'ndi:util:loadStructArray:fileNotFound', ...
                'Loading a missing file should raise the fileNotFound error.');
        end

        function testFieldCountMismatchErrors(testCase)
            % Supplying the wrong number of field names should error.
            f = fullfile(testCase.testDir, 'mismatch.txt');
            fid = fopen(f, 'w');
            fprintf(fid, '%d\t%s\n', 1, 'a');
            fclose(fid);
            testCase.verifyError(@() ndi.util.loadStructArray(f, {'only_one'}), ...
                'ndi:util:loadStructArray:fieldCountMismatch', ...
                'A field-count mismatch should raise an error.');
        end

    end
end
