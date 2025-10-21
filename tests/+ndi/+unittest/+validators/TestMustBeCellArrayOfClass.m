classdef TestMustBeCellArrayOfClass < matlab.unittest.TestCase
    % TestMustBeCellArrayOfClass - tests for the mustBeCellArrayOfClass validator
    %

    methods (Test)

        function test_pass_char(testCase)
            % Test that the validator passes with a cell array of char
            c = {'hello', 'world'};
            f = @() ndi.validators.mustBeCellArrayOfClass(c, 'char');
            testCase.verifyWarningFree(f);
        end

        function test_pass_string(testCase)
            % Test that the validator passes with a cell array of string
            c = {string('hello'), string('world')};
            f = @() ndi.validators.mustBeCellArrayOfClass(c, 'string');
            testCase.verifyWarningFree(f);
        end

        function test_pass_numeric(testCase)
            % Test that the validator passes with a cell array of numeric
            c = {1, 2, 3};
            f = @() ndi.validators.mustBeCellArrayOfClass(c, 'double');
            testCase.verifyWarningFree(f);
        end

        function test_fail_mixed(testCase)
            % Test that the validator fails with a mixed cell array
            c = {'hello', 1};
            f = @() ndi.validators.mustBeCellArrayOfClass(c, 'char');
            testCase.verifyError(f, ?MException);
        end

        function test_fail_not_cell(testCase)
            % Test that the validator fails with a non-cell input
            c = 'hello';
            f = @() ndi.validators.mustBeCellArrayOfClass(c, 'char');
            testCase.verifyError(f, ?MException);
        end

    end
end
