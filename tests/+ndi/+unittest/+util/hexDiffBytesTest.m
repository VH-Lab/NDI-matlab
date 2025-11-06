classdef hexDiffBytesTest < matlab.unittest.TestCase
    % HEXDIFFBYTESTEST - Test for ndi.util.hexDiffBytes
    %

    methods (Test)
        function testIdenticalArrays(testCase)
            % Test with two identical byte arrays
            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([1 2 3 4 5]);

            diff_string = ndi.util.hexDiffBytes(data1, data2);

            testCase.verifyEmpty(diff_string, 'Diff string should be empty for identical arrays.');
        end

        function testDifferentArraysSameSize(testCase)
            % Test with different arrays of the same size
            data1 = uint8([1 2 3 4 5]);
            data2 = uint8([1 2 99 4 5]); % Difference at index 3

            diff_string = ndi.util.hexDiffBytes(data1, data2);

            testCase.verifyNotEmpty(diff_string, 'Diff string should not be empty.');
            testCase.verifyTrue(contains(diff_string, '01 02 63 04 05'), 'Diff string should contain the hex representation of the second array.');
        end

        function testDifferentSizeFirstLonger(testCase)
            % Test when the first array is longer
            data1 = uint8(1:20);
            data2 = uint8(1:10);

            diff_string = ndi.util.hexDiffBytes(data1, data2);

            testCase.verifyNotEmpty(diff_string, 'Diff string should not be empty.');
            testCase.verifyTrue(contains(diff_string, '0B 0C 0D 0E 0F'), 'Diff string should show the extra bytes from the first array.');
        end

        function testDifferentSizeSecondLonger(testCase)
            % Test when the second array is longer
            data1 = uint8(1:10);
            data2 = uint8(1:20);

            diff_string = ndi.util.hexDiffBytes(data1, data2);

            testCase.verifyNotEmpty(diff_string, 'Diff string should not be empty.');
            testCase.verifyTrue(contains(diff_string, '0B 0C 0D 0E 0F'), 'Diff string should show the extra bytes from the second array.');
        end

        function testEmptyArrays(testCase)
            % Test with two empty arrays
            data1 = uint8([]);
            data2 = uint8([]);

            diff_string = ndi.util.hexDiffBytes(data1, data2);

            testCase.verifyEmpty(diff_string, 'Diff string should be empty for two empty arrays.');
        end

        function testOneEmptyArray(testCase)
            % Test with one empty array and one non-empty
            data1 = uint8([1 2 3]);
            data2 = uint8([]);

            diff_string = ndi.util.hexDiffBytes(data1, data2);

            testCase.verifyNotEmpty(diff_string, 'Diff string should not be empty.');
            testCase.verifyTrue(contains(diff_string, '01 02 03'), 'Diff string should show the bytes from the non-empty array.');
        end
    end
end
