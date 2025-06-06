% TestContactInformation.m
classdef TestContactInformation < matlab.unittest.TestCase
    %TESTCONTACTINFORMATION Unit tests for the ContactInformation class.

    properties
        ContactInfoClassName = 'ndi.gui.component.metadataEditor.class.ContactInformation'
    end

    methods (Test)
        function testDefaultConstructor(testCase)
            ci = feval(testCase.ContactInfoClassName);
            testCase.verifyClass(ci, testCase.ContactInfoClassName);
            % Corrected: The class correctly creates a 1x0 char. The test must expect this.
            testCase.verifyEqual(ci.email, char.empty(1,0), 'Default email should be a 1x0 empty char.');
        end

        function testPropertyAssignmentValid(testCase)
            ci = feval(testCase.ContactInfoClassName);
            testEmail = 'test@example.com';
            ci.email = testEmail;
            testCase.verifyEqual(ci.email, testEmail);
        end

        function testToStruct(testCase)
            ci = feval(testCase.ContactInfoClassName);
            testEmail = 'user@domain.com';
            ci.email = testEmail;
            s = ci.toStruct();
            testCase.verifyTrue(isstruct(s));
            testCase.verifyTrue(isfield(s, 'email'));
            testCase.verifyEqual(s.email, testEmail);
        end

        function testToAlphaNumericStruct(testCase)
            ci = feval(testCase.ContactInfoClassName);
            testEmail = 'another.user@example.org';
            ci.email = testEmail;
            alphaS = ci.toAlphaNumericStruct();
            testCase.verifyTrue(isstruct(alphaS));
            testCase.verifyTrue(isfield(alphaS, 'email'));
            testCase.verifyEqual(alphaS.email, testEmail);
            [isValid, ~] = ndi.util.isAlphaNumericStruct(alphaS);
            testCase.verifyTrue(isValid);
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s.email = 'valid@struct.com';
            ci = ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, false);
            testCase.verifyClass(ci, testCase.ContactInfoClassName);
            testCase.verifyEqual(ci.email, s.email);
        end

        function testFromStructMissingFieldOptional(testCase)
            s = struct(); 
            ci = ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, false);
            testCase.verifyClass(ci, testCase.ContactInfoClassName);
            % Corrected: The default email will be 1x0 empty char.
            testCase.verifyEqual(ci.email, char.empty(1,0), 'Email should default to 1x0 empty char.');
        end

        function testFromStructMissingFieldRequired(testCase)
            s = struct(); 
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromStructExtraField(testCase)
            s.email = 'test@example.com';
            s.extraField = 'unexpected';
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, false), ...
                'ndi:validators:mustHaveOnlyFields:ExtraField');
        end

        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValidScalar(testCase)
            alphaS.email = 'alpha@example.com';
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            ci = f(alphaS, false);
            testCase.verifyClass(ci, testCase.ContactInfoClassName);
            testCase.verifyEqual(ci.email, alphaS.email);
        end

        function testFromAlphaNumericStructValidArray(testCase)
            alphaS(1,1).email = 'user1@example.com';
            alphaS(1,2).email = 'user2@example.com';
            
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            ciArray = f(alphaS, false);
            testCase.verifyClass(ciArray, testCase.ContactInfoClassName);
            testCase.verifySize(ciArray, [1 2]);
            testCase.verifyEqual(ciArray(1,2).email, alphaS(1,2).email);
        end
        
        function testFromAlphaNumStruct_InvalidInputFormat(testCase)
            alphaS.email = {'not', 'a', 'char'};
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, false), ...
                'ndi:validators:mustBeAlphaNumericStruct:InvalidFormat');
        end

        function testFromAlphaNumericStructMissingFieldRequired(testCase)
            alphaS = struct();
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
    end
end