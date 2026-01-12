classdef test_mustBeClassnameOfType < matlab.unittest.TestCase

    methods (Test)
        function testValidSubclass(testCase)
            % Should pass for a subclass
            ndi.validators.mustBeClassnameOfType('ndi.calculator', 'ndi.app');
        end

        function testSameClass(testCase)
            % Should pass if class is same as required type
            ndi.validators.mustBeClassnameOfType('ndi.calculator', 'ndi.calculator');
        end

        function testInvalidSubclass(testCase)
            % Should error for a non-subclass
            % ndi.session does not inherit from ndi.calculator
            testCase.verifyError(@() ndi.validators.mustBeClassnameOfType('ndi.session.dir', 'ndi.calculator'), ...
                'ndi:validators:mustBeClassnameOfType:notSubclass');
        end

        function testNonExistentClass(testCase)
            testCase.verifyError(@() ndi.validators.mustBeClassnameOfType('NonExistentClass', 'ndi.app'), ...
                'ndi:validators:mustBeClassnameOfType:classNotFound');
        end

        function testInvalidInputType(testCase)
            testCase.verifyError(@() ndi.validators.mustBeClassnameOfType(123, 'ndi.app'), ...
                'ndi:validators:mustBeClassnameOfType:invalidType');
            testCase.verifyError(@() ndi.validators.mustBeClassnameOfType('ndi.calculator', 123), ...
                'ndi:validators:mustBeClassnameOfType:invalidType');
        end
    end
end
