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
            testCase.verifyEqual(ci.email, char.empty(1,0));
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
            % Verify CellStrDelimiter is also included now
            testCase.verifyTrue(isfield(s, 'CellStrDelimiter'));
            testCase.verifyEqual(s.CellStrDelimiter, ', ');
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
            s.CellStrDelimiter = ';'; % Test with a non-default delimiter
            ci = ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, false);
            testCase.verifyClass(ci, testCase.ContactInfoClassName);
            testCase.verifyEqual(ci.email, s.email);
            testCase.verifyEqual(ci.CellStrDelimiter, ';');
        end

        function testFromStructMissingFieldOptional(testCase)
            s = struct('CellStrDelimiter', '|'); 
            ci = ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, false);
            testCase.verifyClass(ci, testCase.ContactInfoClassName);
            testCase.verifyEqual(ci.email, char.empty(1,0));
            testCase.verifyEqual(ci.CellStrDelimiter, '|');
        end

        function testFromStructMissingFieldRequired(testCase)
            % Corrected: Provide one field so only 'email' is missing.
            s = struct('CellStrDelimiter', ', '); 
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromStructExtraField(testCase)
            s.email = 'test@example.com';
            s.CellStrDelimiter = ', ';
            s.extraField = 'unexpected';
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.ContactInfoClassName, s, false), ...
                'ndi:validators:mustHaveOnlyFields:ExtraField');
        end

        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValidScalar(testCase)
            alphaS.email = 'alpha@example.com';
            alphaS.CellStrDelimiter = ';';
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            ci = f(alphaS);
            testCase.verifyClass(ci, testCase.ContactInfoClassName);
            testCase.verifyEqual(ci.email, alphaS.email);
            testCase.verifyEqual(ci.CellStrDelimiter, ';');
        end

        function testFromAlphaNumericStructValidArray(testCase)
            alphaS(1,1).email = 'user1@example.com';
            alphaS(1,1).CellStrDelimiter = ', ';
            alphaS(1,2).email = 'user2@example.com';
            alphaS(1,2).CellStrDelimiter = '|';
            
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            ciArray = f(alphaS);
            testCase.verifyClass(ciArray, testCase.ContactInfoClassName);
            testCase.verifySize(ciArray, [1 2]);
            testCase.verifyEqual(ciArray(1,2).email, alphaS(1,2).email);
            testCase.verifyEqual(ciArray(1,2).CellStrDelimiter, '|');
        end
        
        function testFromAlphaNumStruct_InvalidInputFormat(testCase)
            alphaS.email = {'not', 'a', 'char'};
            alphaS.CellStrDelimiter = ', ';
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS), ...
                'ndi:validators:mustBeAlphaNumericStruct:InvalidFormat');
        end

        function testFromAlphaNumericStructMissingFieldRequired(testCase)
            % Corrected: Provide CellStrDelimiter so only 'email' is missing
            alphaS = struct('CellStrDelimiter', ', ');
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end

        function testFromAlphaNumericStructExtraField(testCase)
            alphaS.email = 'test@example.com';
            alphaS.CellStrDelimiter = ', ';
            alphaS.extraField = 'extra';
            f = str2func([testCase.ContactInfoClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
    end
end
