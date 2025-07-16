classdef mustBeIDTest < matlab.unittest.TestCase
    % MUSTBEIDTEST - Test for the ndi.validators.mustBeID validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustBeID function. It checks that the
    %   validator correctly accepts valid NDI ID strings and throws
    %   appropriate errors for invalid formats.
    %

    methods (Test)

        function testValidID(testCase)
            % Test with a correctly formatted NDI ID
            validID = '4126919195e6b5af_40d651024919a2e4';
            testCase.verifyWarningFree(@() ndi.validators.mustBeID(validID));
        end

        function testValidIDAsString(testCase)
            % Test with a correctly formatted NDI ID as a string scalar
            validID = "4126919195e6b5af_40d651024919a2e4";
            testCase.verifyWarningFree(@() ndi.validators.mustBeID(validID));
        end

        function testWrongLengthTooShort(testCase)
            % Test with an ID that is too short
            invalidID = 'short_id';
            testCase.verifyError(@() ndi.validators.mustBeID(invalidID), ...
                ?MException);
        end

        function testWrongLengthTooLong(testCase)
            % Test with an ID that is too long
            invalidID = 'this_id_is_definitely_way_too_long_to_be_a_valid_ndi_id';
            testCase.verifyError(@() ndi.validators.mustBeID(invalidID), ...
                ?MException);
        end

        function testMissingUnderscore(testCase)
            % Test with an ID of the correct length but missing the underscore
            invalidID = '4126919195e6b5afX40d651024919a2e4';
            testCase.verifyError(@() ndi.validators.mustBeID(invalidID), ...
                ?MException);
        end

        function testInvalidCharacters(testCase)
            % Test with an ID that contains non-alphanumeric characters
            invalidID = '4126919195e6b5af_40d651024919a2e!'; % '!' is invalid
            testCase.verifyError(@() ndi.validators.mustBeID(invalidID), ...
                ?MException);
        end

        function testNonCharRowVector(testCase)
            % Test with a column vector char array
            invalidID = ['a';'b']; % a 2x1 char array (column vector)
            testCase.verifyError(@() ndi.validators.mustBeID(invalidID), ...
                'NDI:Validation:InvalidID:NotCharRowVector');
        end

        function testNonTextScalarInput(testCase)
            % Test with a numeric input
            invalidID = 12345;
            testCase.verifyError(@() ndi.validators.mustBeID(invalidID), ...
                ?MException);
        end

    end
end
