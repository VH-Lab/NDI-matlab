classdef mustBeNumericClassTest < matlab.unittest.TestCase
    % MUSTBENUMERICCLASSTEST - Test for the ndi.validators.mustBeNumericClass validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustBeNumericClass function. It checks that the
    %   validator correctly accepts all valid numeric and logical class names
    %   and throws appropriate errors for invalid inputs.
    %

    properties (TestParameter)
        % A parameter that provides all valid class names to the test method.
        validClassName = { ...
            'uint8', 'uint16', 'uint32', 'uint64', ...
            'int8', 'int16', 'int32', 'int64', ...
            'single', 'double', 'logical' ...
        };
    end

    methods (Test)

        function testValidNumericClasses(testCase, validClassName)
            % This test is executed for each value in the validClassName parameter.
            % It verifies that each valid class name passes the validation without error.
            
            testCase.verifyWarningFree(@() ndi.validators.mustBeNumericClass(validClassName));
        end

        function testInvalidClassName(testCase)
            % Test with a class name that is not a valid numeric/logical type
            invalidName = 'char';
            
            % Verify that the function throws the correct error
            testCase.verifyError(@() ndi.validators.mustBeNumericClass(invalidName), ...
                'validation:InvalidNumericClass');
        end

        function testNonStringInput(testCase)
            % Test with an input that is not a string or char array
            notAString = 123;
            
            % Verify that the function throws an error for invalid input type
            testCase.verifyError(@() ndi.validators.mustBeNumericClass(notAString), ...
                'validation:InvalidInputType');
        end

        function testCaseSensitivity(testCase)
            % Test that the validator is case-sensitive
            invalidName = 'Double'; % Incorrect case
            
            % Verify that the function throws an error
            testCase.verifyError(@() ndi.validators.mustBeNumericClass(invalidName), ...
                'validation:InvalidNumericClass');
        end

        function testEmptyInput(testCase)
            % Test with an empty char array, which is not a valid class name
            emptyInput = '';
            
            % Verify that the function throws an error
            testCase.verifyError(@() ndi.validators.mustBeNumericClass(emptyInput), ...
                'validation:InvalidNumericClass');
        end

    end
end
