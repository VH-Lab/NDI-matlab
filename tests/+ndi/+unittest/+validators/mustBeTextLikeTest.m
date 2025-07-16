classdef mustBeTextLikeTest < matlab.unittest.TestCase
    % MUSTBETEXTLIKETEST - Test for the ndi.validators.mustBeTextLike validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustBeTextLike function.
    %

    methods (Test)

        function testValidCharArray(testCase)
            % Test that a valid character array passes
            validInput = 'this is a char array';
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testValidStringScalar(testCase)
            % Test that a valid string scalar passes
            validInput = "this is a string";
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testValidCellArrayOfChars(testCase)
            % Test that a cell array of character arrays passes
            validInput = {'hello', 'world'};
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testValidCellArrayOfStrings(testCase)
            % Test that a cell array of strings passes
            validInput = {"hello", "world"};
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testValidCellArrayOfMixedText(testCase)
            % Test that a cell array of mixed char and string passes
            validInput = {'hello', "world"};
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testEmptyCharArray(testCase)
            % Test that an empty character array is valid
            validInput = '';
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testEmptyString(testCase)
            % Test that an empty string is valid
            validInput = "";
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testEmptyCellArray(testCase)
            % Test that an empty cell array is valid
            validInput = {};
            testCase.verifyWarningFree(@() ndi.validators.mustBeTextLike(validInput));
        end

        function testInvalidNumericInput(testCase)
            % Test that a numeric input throws an error
            invalidInput = 123;
            testCase.verifyError(@() ndi.validators.mustBeTextLike(invalidInput), ...
                'ndi:validators:mustBeTextLike:InvalidType');
        end

        function testInvalidStructInput(testCase)
            % Test that a struct input throws an error
            invalidInput = struct('a', 1);
            testCase.verifyError(@() ndi.validators.mustBeTextLike(invalidInput), ...
                'ndi:validators:mustBeTextLike:InvalidType');
        end

        function testInvalidCellWithNumeric(testCase)
            % Test that a cell array containing a numeric value throws an error
            invalidInput = {'text', 123};
            testCase.verifyError(@() ndi.validators.mustBeTextLike(invalidInput), ...
                'ndi:validators:mustBeTextLike:InvalidType');
        end

    end
end
