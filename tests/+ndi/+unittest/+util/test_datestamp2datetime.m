classdef test_datestamp2datetime < matlab.unittest.TestCase
    %TEST_DATESTAMP2DATETIME Unit tests for the ndi.util.datestamp2datetime function.
    %
    %   To run these tests, you must have the ndi.util.datestamp2datetime function
    %   on your MATLAB path.
    %
    %   Example:
    %       results = runtests('ndi.unittest.util.test_datestamp2datetime');
    %

    methods (Test)
        % Test a valid datestamp string.
        function testValidDatestamp(testCase)
            datestampStr = '2023-10-26T10:30:00.123+00:00';
            expectedDatetime = datetime('2023-10-26T10:30:00.123', 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC');

            actualDatetime = ndi.util.datestamp2datetime(datestampStr);

            testCase.verifyEqual(actualDatetime, expectedDatetime);
        end

        % Test a datestamp at the beginning of a year.
        function testBeginningOfYear(testCase)
            datestampStr = '2025-01-01T00:00:00.000+00:00';
            expectedDatetime = datetime('2025-01-01T00:00:00.000', 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC');

            actualDatetime = ndi.util.datestamp2datetime(datestampStr);

            testCase.verifyEqual(actualDatetime, expectedDatetime);
        end

        % Test a datestamp with a different timezone that should be converted to UTC.
        function testDifferentTimezone(testCase)
            datestampStr = '2023-10-26T15:30:00.123+05:00'; % 5 hours ahead of UTC
            expectedDatetime = datetime('2023-10-26T10:30:00.123', 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC');

            actualDatetime = ndi.util.datestamp2datetime(datestampStr);

            testCase.verifyEqual(actualDatetime, expectedDatetime);
        end

        % Test that an invalid format raises an error.
        function testInvalidFormatError(testCase)
            invalidDatestampStr = '2023/10/26 10:30:00';

            testCase.verifyError(@() ndi.util.datestamp2datetime(invalidDatestampStr), 'MATLAB:datetime:ParseErr');
        end

        % Test that a non-char input raises an error
        function testNonCharInput(testCase)
            % Use a struct, which is unambiguously not a char array, to test
            % the arguments block validation. A numeric input like 12345 gets
            % implicitly converted to a char, bypassing this validation.
            nonCharInput = struct('field', 'value');

            testCase.verifyError(@() ndi.util.datestamp2datetime(nonCharInput), 'MATLAB:validation:UnableToConvert');
        end

    end
end