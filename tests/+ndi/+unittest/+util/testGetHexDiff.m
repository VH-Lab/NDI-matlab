classdef testGetHexDiff < matlab.unittest.TestCase
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
            rmdir(testCase.testDir, 's');
        end
    end

    methods (Test)
        function testIdenticalFiles(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            data = uint8(randi([0 255], 1, 100));

            fid = fopen(file1, 'w');
            fwrite(fid, data);
            fclose(fid);

            fid = fopen(file2, 'w');
            fwrite(fid, data);
            fclose(fid);

            [are_identical, diff_output] = ndi.util.getHexDiff(file1, file2);
            testCase.verifyTrue(are_identical);
            testCase.verifyTrue(contains(diff_output, 'Files are identical'));
        end

        function testDifferentFiles(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([1 2 3 4 6]);

            fid = fopen(file1, 'w');
            fwrite(fid, data1);
            fclose(fid);

            fid = fopen(file2, 'w');
            fwrite(fid, data2);
            fclose(fid);

            [are_identical, ~] = ndi.util.getHexDiff(file1, file2);
            testCase.verifyFalse(are_identical);
        end

        function testDifferentLengthFiles(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([1 2 3 4 5 6]);

            fid = fopen(file1, 'w');
            fwrite(fid, data1);
            fclose(fid);

            fid = fopen(file2, 'w');
            fwrite(fid, data2);
            fclose(fid);

            [are_identical, ~] = ndi.util.getHexDiff(file1, file2);
            testCase.verifyFalse(are_identical);
        end

        function testEmptyFiles(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            fid = fopen(file1, 'w');
            fclose(fid);

            fid = fopen(file2, 'w');
            fclose(fid);

            [are_identical, ~] = ndi.util.getHexDiff(file1, file2);
            testCase.verifyTrue(are_identical);
        end

        function testStartByteOption(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([0 0 3 4 5]);

            fid = fopen(file1, 'w');
            fwrite(fid, data1);
            fclose(fid);

            fid = fopen(file2, 'w');
            fwrite(fid, data2);
            fclose(fid);

            [are_identical, ~] = ndi.util.getHexDiff(file1, file2, 'StartByte', 2);
            testCase.verifyTrue(are_identical);
        end

        function testStopByteOption(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([1 2 3 0 0]);

            fid = fopen(file1, 'w');
            fwrite(fid, data1);
            fclose(fid);

            fid = fopen(file2, 'w');
            fwrite(fid, data2);
            fclose(fid);

            [are_identical, ~] = ndi.util.getHexDiff(file1, file2, 'StopByte', 2);
            testCase.verifyTrue(are_identical);
        end
    end
end
