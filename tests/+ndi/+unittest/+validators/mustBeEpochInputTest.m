classdef mustBeEpochInputTest < matlab.unittest.TestCase
    % MUSTBEPOCHINPUTTEST - Test for the ndi.validators.mustBeEpochInput validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustBeEpochInput function. It checks that the
    %   validator correctly accepts valid inputs and throws appropriate errors
    %   for invalid inputs.
    %

    methods (Test)

        function testValidPositiveInteger(testCase)
            % Test that a positive integer scalar passes
            validInput = 5;
            testCase.verifyWarningFree(@() ndi.validators.mustBeEpochInput(validInput));
        end

        function testValidCharacterArray(testCase)
            % Test that a character array (row vector) passes
            validInput = 't00001';
            testCase.verifyWarningFree(@() ndi.validators.mustBeEpochInput(validInput));
        end

        function testValidStringScalar(testCase)
            % Test that a string scalar passes
            validInput = "t00001";
            testCase.verifyWarningFree(@() ndi.validators.mustBeEpochInput(validInput));
        end

        function testInvalidIntegerArray(testCase)
            % Test that an array of integers throws an error
            invalidInput = [1 2 3];
            testCase.verifyError(@() ndi.validators.mustBeEpochInput(invalidInput), ?MException);
        end

        function testInvalidNegativeInteger(testCase)
            % Test that a negative integer throws an error
            invalidInput = -5;
            testCase.verifyError(@() ndi.validators.mustBeEpochInput(invalidInput), ?MException);
        end

        function testInvalidZero(testCase)
            % Test that zero throws an error
            invalidInput = 0;
            testCase.verifyError(@() ndi.validators.mustBeEpochInput(invalidInput), ?MException);
        end

        function testInvalidNonInteger(testCase)
            % Test that a non-integer number throws an error
            invalidInput = 5.5;
            testCase.verifyError(@() ndi.validators.mustBeEpochInput(invalidInput), ?MException);
        end

        function testInvalidStringArray(testCase)
            % Test that a string array throws an error
            invalidInput = ["t00001", "t00002"];
            testCase.verifyError(@() ndi.validators.mustBeEpochInput(invalidInput), ?MException);
        end

        function testInvalidCellArray(testCase)
            % Test that a cell array throws an error
            invalidInput = {'t00001'};
            testCase.verifyError(@() ndi.validators.mustBeEpochInput(invalidInput), ?MException);
        end

    end
end
