classdef mustMatchRegexTest < matlab.unittest.TestCase
    % MUSTMATCHREGEXTEST - Test for the ndi.validators.mustMatchRegex validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustMatchRegex function.
    %

    methods (Test)

        function testValidMatch(testCase)
            % Test with a value that perfectly matches the pattern
            value = 'ABC12345';
            pattern = '^[A-Z]{3}\d{5}$';
            testCase.verifyWarningFree(@() ndi.validators.mustMatchRegex(value, pattern));
        end

        function testValidMatchAsString(testCase)
            % Test with a string scalar value
            value = "ABC12345";
            pattern = '^[A-Z]{3}\d{5}$';
            testCase.verifyWarningFree(@() ndi.validators.mustMatchRegex(value, pattern));
        end

        function testNoMatch(testCase)
            % Test with a value that does not match the pattern
            value = 'abc12345'; % Fails due to case
            pattern = '^[A-Z]{3}\d{5}$';
            testCase.verifyError(@() ndi.validators.mustMatchRegex(value, pattern), ...
                'ndi:validators:mustMatchRegex:NoMatch');
        end

        function testPartialMatchFails(testCase)
            % Test that the validator requires a full string match
            value = 'ABC12345extra';
            pattern = '^[A-Z]{3}\d{5}'; % Pattern only matches the start
            % The validator implicitly anchors with ^ and $, so this should fail
            testCase.verifyError(@() ndi.validators.mustMatchRegex(value, pattern), ...
                'ndi:validators:mustMatchRegex:NoMatch');
        end

        function testInvalidInputTypeNumeric(testCase)
            % Test with a numeric input, which is invalid
            value = 12345;
            pattern = '\d+';
            testCase.verifyError(@() ndi.validators.mustMatchRegex(value, pattern), ...
                'ndi:validators:mustMatchRegex:InvalidInputType');
        end

        function testInvalidInputTypeCell(testCase)
            % Test with a cell array input, which is invalid
            value = {'ABC12345'};
            pattern = '.*';
            testCase.verifyError(@() ndi.validators.mustMatchRegex(value, pattern), ...
                'ndi:validators:mustMatchRegex:InvalidInputType');
        end

        function testInvalidPatternType(testCase)
            % Test with an invalid pattern type
            value = 'some_value';
            pattern = 123; % Pattern must be char or string
            testCase.verifyError(@() ndi.validators.mustMatchRegex(value, pattern), ...
                'ndi:validators:mustMatchRegex:InvalidPatternType');
        end

    end
end
