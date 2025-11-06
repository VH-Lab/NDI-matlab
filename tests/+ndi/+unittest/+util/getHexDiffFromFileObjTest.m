classdef getHexDiffFromFileObjTest < matlab.unittest.TestCase
    % GETTEXTDIFFFROMFILEOBJTEST - Test for ndi.util.getHexDiffFromFileObj
    %

    properties
        testDir
    end

    methods (TestMethodSetup)
        function createTestDir(testCase)
            % Create a temporary directory for test files
            testCase.testDir = tempname;
            mkdir(testCase.testDir);
        end
    end

    methods (TestMethodTeardown)
        function removeTestDir(testCase)
            % Remove the temporary directory and its contents
            if exist(testCase.testDir, 'dir')
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods (Test)
        function testIdenticalFiles(testCase)
            % Test case for two identical files

            % 1. Create two identical files
            file1_path = fullfile(testCase.testDir, 'file1.bin');
            file2_path = fullfile(testCase.testDir, 'file2.bin');

            content = uint8(randi([0 255], 1, 2048)); % 2KB of random data

            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, content, 'uint8');
            fclose(fid1);

            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, content, 'uint8');
            fclose(fid2);

            % 2. Open files and get file objects
            file_obj1 = did.file.fileobj();
            file_obj1.fopen('r', 'n', file1_path);
            cleanup1 = onCleanup(@() file_obj1.fclose());

            file_obj2 = did.file.fileobj();
            file_obj2.fopen('r', 'n', file2_path);
            cleanup2 = onCleanup(@() file_obj2.fclose());

            % 3. Call the function
            [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);

            % 4. Assert the results
            testCase.verifyTrue(are_identical, 'Files should be reported as identical.');
            testCase.verifyEmpty(diff_output, 'Diff output should be empty for identical files.');
        end

        function testDifferentContentSameSize(testCase)
            % Test case for two files with different content but the same size

            file1_path = fullfile(testCase.testDir, 'file1.bin');
            file2_path = fullfile(testCase.testDir, 'file2.bin');

            content1 = uint8(randi([0 255], 1, 1024));
            content2 = content1;
            content2(512) = bitxor(content2(512), 255); % Introduce a difference

            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, content1, 'uint8');
            fclose(fid1);

            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, content2, 'uint8');
            fclose(fid2);

            file_obj1 = did.file.fileobj();
            file_obj1.fopen('r', 'n', file1_path);
            cleanup1 = onCleanup(@() file_obj1.fclose());

            file_obj2 = did.file.fileobj();
            file_obj2.fopen('r', 'n', file2_path);
            cleanup2 = onCleanup(@() file_obj2.fclose());

            [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);

            testCase.verifyFalse(are_identical, 'Files should be reported as different.');
            testCase.verifyNotEmpty(diff_output, 'Diff output should not be empty for different files.');
        end

        function testDifferentSizeFirstLonger(testCase)
            % Test case for files where the first is longer

            file1_path = fullfile(testCase.testDir, 'file1.bin');
            file2_path = fullfile(testCase.testDir, 'file2.bin');

            content1 = uint8(randi([0 255], 1, 1024));
            content2 = content1(1:512); % Shorter file

            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, content1, 'uint8');
            fclose(fid1);

            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, content2, 'uint8');
            fclose(fid2);

            file_obj1 = did.file.fileobj();
            file_obj1.fopen('r', 'n', file1_path);
            cleanup1 = onCleanup(@() file_obj1.fclose());

            file_obj2 = did.file.fileobj();
            file_obj2.fopen('r', 'n', file2_path);
            cleanup2 = onCleanup(@() file_obj2.fclose());

            [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);

            testCase.verifyFalse(are_identical, 'Files should be reported as different due to size.');
            testCase.verifyNotEmpty(diff_output, 'Diff output should not be empty.');
            testCase.verifyTrue(contains(diff_output, 'different sizes'), 'Diff output should mention size difference.');
        end

        function testDifferentSizeSecondLonger(testCase)
            % Test case for files where the second is longer

            file1_path = fullfile(testCase.testDir, 'file1.bin');
            file2_path = fullfile(testCase.testDir, 'file2.bin');

            content2 = uint8(randi([0 255], 1, 1024));
            content1 = content2(1:512); % Shorter file

            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, content1, 'uint8');
            fclose(fid1);

            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, content2, 'uint8');
            fclose(fid2);

            file_obj1 = did.file.fileobj();
            file_obj1.fopen('r', 'n', file1_path);
            cleanup1 = onCleanup(@() file_obj1.fclose());

            file_obj2 = did.file.fileobj();
            file_obj2.fopen('r', 'n', file2_path);
            cleanup2 = onCleanup(@() file_obj2.fclose());

            [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);

            testCase.verifyFalse(are_identical, 'Files should be reported as different due to size.');
            testCase.verifyNotEmpty(diff_output, 'Diff output should not be empty.');
            testCase.verifyTrue(contains(diff_output, 'different sizes'), 'Diff output should mention size difference.');
        end

        function testEmptyFiles(testCase)
            % Test case for two empty files

            file1_path = fullfile(testCase.testDir, 'file1.bin');
            file2_path = fullfile(testCase.testDir, 'file2.bin');

            fclose(fopen(file1_path, 'w'));
            fclose(fopen(file2_path, 'w'));

            file_obj1 = did.file.fileobj();
            file_obj1.fopen('r', 'n', file1_path);
            cleanup1 = onCleanup(@() file_obj1.fclose());

            file_obj2 = did.file.fileobj();
            file_obj2.fopen('r', 'n', file2_path);
            cleanup2 = onCleanup(@() file_obj2.fclose());

            [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);

            testCase.verifyTrue(are_identical, 'Empty files should be reported as identical.');
            testCase.verifyEmpty(diff_output, 'Diff output should be empty for empty files.');
        end

    end
end
