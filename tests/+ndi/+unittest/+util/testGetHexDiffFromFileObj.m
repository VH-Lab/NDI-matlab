classdef testGetHexDiffFromFileObj < matlab.unittest.TestCase
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

            fid1 = fopen(file1, 'w');
            fwrite(fid1, data);
            fclose(fid1);

            fid2 = fopen(file2, 'w');
            fwrite(fid2, data);
            fclose(fid2);

            fid1 = fopen(file1, 'r');
            cleanup1 = onCleanup(@() fclose(fid1));
            fid2 = fopen(file2, 'r');
            cleanup2 = onCleanup(@() fclose(fid2));

            [are_identical, ~] = ndi.util.getHexDiffFromFileObj(fid1, fid2);
            testCase.verifyTrue(are_identical);
        end

        function testDifferentFiles(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([1 2 3 4 6]);

            fid1 = fopen(file1, 'w');
            fwrite(fid1, data1);
            fclose(fid1);

            fid2 = fopen(file2, 'w');
            fwrite(fid2, data2);
            fclose(fid2);

            fid1 = fopen(file1, 'r');
            cleanup1 = onCleanup(@() fclose(fid1));
            fid2 = fopen(file2, 'r');
            cleanup2 = onCleanup(@() fclose(fid2));

            [are_identical, ~] = ndi.util.getHexDiffFromFileObj(fid1, fid2);
            testCase.verifyFalse(are_identical);
        end
    end
end
