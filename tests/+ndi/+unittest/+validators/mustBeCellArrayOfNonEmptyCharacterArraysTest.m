classdef mustBeCellArrayOfNonEmptyCharacterArraysTest < matlab.unittest.TestCase
    % MUSTBECELLARRAYOFNONEMPTYCHARACTERARRAYSTEST - Test for the validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays function.
    %

    methods (Test)

        function testValidInput(testCase)
            % Test that a valid cell array of non-empty char arrays passes
            validInput = {'hello', 'world', 'test'};
            testCase.verifyWarningFree(@() ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(validInput));
        end

        function testValidInputWithStrings(testCase)
            % Test with a mix of char and string, should fail as it expects char
            mixedInput = {'hello', "world"};
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(mixedInput), ...
                'ndi:validators:mustBeCellArrayOfNonEmptyCharacterArrays:InvalidCellContent');
        end

        function testEmptyCellArray(testCase)
            % Test that an empty cell array is valid
            emptyCell = {};
            testCase.verifyWarningFree(@() ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(emptyCell));
        end

        function testNonCellInput(testCase)
            % Test that a non-cell array input throws an error
            notACell = 'this is not a cell array';
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(notACell), ...
                'ndi:validators:mustBeCellArrayOfNonEmptyCharacterArrays:InputNotCell');
        end

        function testCellWithEmptyCharArray(testCase)
            % Test that a cell array containing an empty char array throws an error
            invalidContent = {'hello', '', 'world'};
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(invalidContent), ...
                'ndi:validators:mustBeCellArrayOfNonEmptyCharacterArrays:InvalidCellContent');
        end

        function testCellWithNonCharContent(testCase)
            % Test that a cell array containing a non-char element throws an error
            invalidContent = {'hello', 123, 'world'};
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(invalidContent), ...
                'ndi:validators:mustBeCellArrayOfNonEmptyCharacterArrays:InvalidCellContent');
        end

        function testCellWithMixedValidAndInvalid(testCase)
            % Test a mix of valid and invalid elements
            mixedContent = {'valid1', [], 'valid2'}; % [] is not a char
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(mixedContent), ...
                'ndi:validators:mustBeCellArrayOfNonEmptyCharacterArrays:InvalidCellContent');
        end

    end
end
