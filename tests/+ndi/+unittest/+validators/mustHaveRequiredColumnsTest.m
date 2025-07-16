classdef mustHaveRequiredColumnsTest < matlab.unittest.TestCase
    % MUSTHAVEREQUIREDCOLUMNSTEST - Test for the ndi.validators.mustHaveRequiredColumns validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustHaveRequiredColumns function.
    %

    properties
        SampleTable
    end

    methods (TestMethodSetup)
        function createSampleTable(testCase)
            % Create a sample table for use in the tests
            testCase.SampleTable = table([1; 2], {'A'; 'B'}, [true; false], ...
                'VariableNames', {'NumCol', 'StrCol', 'LogCol'});
        end
    end

    methods (Test)

        function testWithAllColumnsPresent(testCase)
            % Test when all required columns are present
            required = {'NumCol', 'LogCol'};
            testCase.verifyWarningFree(@() ndi.validators.mustHaveRequiredColumns(testCase.SampleTable, required));
        end

        function testWithSingleColumnPresent(testCase)
            % Test with a single required column that is present
            required = 'StrCol';
            testCase.verifyWarningFree(@() ndi.validators.mustHaveRequiredColumns(testCase.SampleTable, required));
        end

        function testMissingOneColumn(testCase)
            % Test when one of the required columns is missing
            required = {'NumCol', 'MissingCol'};
            testCase.verifyError(@() ndi.validators.mustHaveRequiredColumns(testCase.SampleTable, required), ...
                'ndi:validation:MissingColumns');
        end

        function testMissingMultipleColumns(testCase)
            % Test when multiple required columns are missing
            required = {'Missing1', 'StrCol', 'Missing2'};
            testCase.verifyError(@() ndi.validators.mustHaveRequiredColumns(testCase.SampleTable, required), ...
                'ndi:validation:MissingColumns');
        end

        function testEmptyRequiredList(testCase)
            % Test with an empty list of required columns (should always pass)
            required = {};
            testCase.verifyWarningFree(@() ndi.validators.mustHaveRequiredColumns(testCase.SampleTable, required));
        end

        function testCaseSensitivity(testCase)
            % Test that column name matching is case-sensitive
            required = {'numcol'}; % Incorrect case
            testCase.verifyError(@() ndi.validators.mustHaveRequiredColumns(testCase.SampleTable, required), ...
                'ndi:validation:MissingColumns');
        end

        function testOnEmptyTable(testCase)
            % Test validator on an empty table
            emptyTable = table();
            required = {'AnyColumn'};
            testCase.verifyError(@() ndi.validators.mustHaveRequiredColumns(emptyTable, required), ...
                'ndi:validation:MissingColumns');
        end

    end
end
