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

            fid1_w = fopen(file1, 'w');
            fwrite(fid1_w, data);
            fclose(fid1_w);

            fid2_w = fopen(file2, 'w');
            fwrite(fid2_w, data);
            fclose(fid2_w);

            fid1 = fopen(file1, 'r');
            cleanup1 = onCleanup(@() fclose(fid1));
            fid2 = fopen(file2, 'r');
            cleanup2 = onCleanup(@() fclose(fid2));

            file_obj1 = struct('fid', fid1);
            file_obj2 = struct('fid', fid2);

            [are_identical, ~] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);
            testCase.verifyTrue(are_identical);
        end

        function testDifferentFiles(testCase)
            file1 = fullfile(testCase.testDir, 'file1.bin');
            file2 = fullfile(testCase.testDir, 'file2.bin');

            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([1 2 3 4 6]);

            fid1_w = fopen(file1, 'w');
            fwrite(fid1_w, data1);
            fclose(fid1_w);

            fid2_w = fopen(file2, 'w');
            fwrite(fid2_w, data2);
            fclose(fid2_w);

            fid1 = fopen(file1, 'r');
            cleanup1 = onCleanup(@() fclose(fid1));
            fid2 = fopen(file2, 'r');
            cleanup2 = onCleanup(@() fclose(fid2));

            file_obj1 = struct('fid', fid1);
            file_obj2 = struct('fid', fid2);

            [are_identical, ~] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);
            testCase.verifyFalse(are_identical);
        end
    end
end
