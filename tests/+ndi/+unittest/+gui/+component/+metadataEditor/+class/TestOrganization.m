% TestOrganization.m
classdef TestOrganization < matlab.unittest.TestCase
    %TESTORGANIZATION Unit tests for the ndi.gui.component.metadataEditor.class.Organization class.

    properties
        OrgClassName = 'ndi.gui.component.metadataEditor.class.Organization'
        OrgIdClassName = 'ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            org = feval(testCase.OrgClassName);
            testCase.verifyClass(org, testCase.OrgClassName);
            testCase.verifyEqual(org.fullName, char.empty(1,0));
            testCase.verifyClass(org.DigitalIdentifier, testCase.OrgIdClassName);
            testCase.verifyEqual(org.DigitalIdentifier.identifier, char.empty(1,0));
            testCase.verifyEqual(org.DigitalIdentifier.type, char.empty(1,0));
        end

        function testPropertyAssignmentValid(testCase)
            org = feval(testCase.OrgClassName);
            
            org.fullName = 'Neurodata Inc.';
            testCase.verifyEqual(org.fullName, 'Neurodata Inc.');

            newId = feval(testCase.OrgIdClassName);
            newId.identifier = 'RORID:123';
            newId.type = 'RORID';
            org.DigitalIdentifier = newId;
            testCase.verifySameHandle(org.DigitalIdentifier, newId);
            testCase.verifyEqual(org.DigitalIdentifier.identifier, 'RORID:123');
        end
        
        function testPropertyValidationFullName(testCase)
            org = feval(testCase.OrgClassName);
            % Corrected: Use try/catch and assign a struct to reliably trigger error.
            try
                org.fullName = struct('a', 1);
                testCase.fail('An error was expected but not thrown for non-char assignment.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validation:UnableToConvert');
            end
        end

        function testPropertyValidationDigitalIdentifier(testCase)
            org = feval(testCase.OrgClassName);
            % Corrected: Use try/catch to test assigning wrong type (struct instead of object).
            try
                org.DigitalIdentifier = struct('identifier', 'bad');
                testCase.fail('An error was expected but not thrown for invalid object assignment.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validation:UnableToConvert');
            end
        end

        function testToStruct(testCase)
            org = feval(testCase.OrgClassName);
            org.fullName = 'Test Org';
            org.DigitalIdentifier.identifier = 'ID001';
            org.DigitalIdentifier.type = 'GRIDID';
            
            s = org.toStruct();
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.fullName, 'Test Org');
            testCase.verifyTrue(isstruct(s.DigitalIdentifier));
            testCase.verifyEqual(s.DigitalIdentifier.identifier, 'ID001');
            testCase.verifyEqual(s.DigitalIdentifier.type, 'GRIDID');
        end

        function testToAlphaNumericStruct(testCase)
            org = feval(testCase.OrgClassName);
            org.fullName = 'Alpha Org';
            org.DigitalIdentifier.identifier = 'ID002';
            org.DigitalIdentifier.type = 'RORID';

            alphaS = org.toAlphaNumericStruct();
            testCase.verifyTrue(isstruct(alphaS));
            testCase.verifyEqual(alphaS.fullName, 'Alpha Org');
            testCase.verifyTrue(isstruct(alphaS.DigitalIdentifier));
            testCase.verifyEqual(alphaS.DigitalIdentifier.identifier, 'ID002');
            testCase.verifyEqual(alphaS.DigitalIdentifier.type, 'RORID');

            [isValid, ~] = ndi.util.isAlphaNumericStruct(alphaS);
            testCase.verifyTrue(isValid);
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s.fullName = 'Struct Org';
            s.DigitalIdentifier = struct('identifier', 'ID_S1', 'type', 'RRID');
            
            org = ndi.util.StructSerializable.fromStruct(testCase.OrgClassName, s, false);
            testCase.verifyClass(org, testCase.OrgClassName);
            testCase.verifyEqual(org.fullName, 'Struct Org');
            testCase.verifyEqual(org.DigitalIdentifier.identifier, 'ID_S1');
            testCase.verifyEqual(org.DigitalIdentifier.type, 'RRID');
        end

        function testFromStructMissingFieldsOptional(testCase)
            s = struct('fullName', 'Partial Org');
            org = ndi.util.StructSerializable.fromStruct(testCase.OrgClassName, s, false);
            testCase.verifyClass(org, testCase.OrgClassName);
            testCase.verifyEqual(org.fullName, 'Partial Org');
            testCase.verifyEqual(org.DigitalIdentifier.identifier, char.empty(1,0));
        end

        function testFromStructMissingFieldRequired(testCase)
            s = struct('fullName', 'Needs All Org');
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.OrgClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromStructExtraField(testCase)
            s.fullName = 'Extra Field Org';
            s.DigitalIdentifier = struct('identifier', 'ID_S_EXTRA', 'type', 'GRIDID');
            s.extraInfo = 'This should not be here';
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.OrgClassName, s, false), ...
                'ndi:validators:mustHaveOnlyFields:ExtraField');
        end

        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValidScalar(testCase)
            alphaS.fullName = 'AlphaScalar Org';
            alphaS.DigitalIdentifier = struct('identifier', 'AS_ID1', 'type', 'rorid');
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            org = f(alphaS, false);
            
            testCase.verifyClass(org, testCase.OrgClassName);
            testCase.verifyEqual(org.fullName, 'AlphaScalar Org');
            testCase.verifyEqual(org.DigitalIdentifier.identifier, 'AS_ID1');
            testCase.verifyEqual(org.DigitalIdentifier.type, 'RORID');
        end

        function testFromAlphaNumericStructValidArray(testCase)
            alphaS_array(1,1).fullName = 'Org A';
            alphaS_array(1,1).DigitalIdentifier = struct('identifier', 'A_ID', 'type', 'GRIDID');
            alphaS_array(1,2).fullName = 'Org B';
            alphaS_array(1,2).DigitalIdentifier = struct('identifier', 'B_ID', 'type', 'rrid');
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            orgArray = f(alphaS_array, false);
            
            testCase.verifyClass(orgArray, testCase.OrgClassName);
            testCase.verifySize(orgArray, [1 2]);
            
            testCase.verifyEqual(orgArray(1,1).fullName, 'Org A');
            testCase.verifyEqual(orgArray(1,1).DigitalIdentifier.type, 'GRIDID');
            testCase.verifyEqual(orgArray(1,2).fullName, 'Org B');
            testCase.verifyEqual(orgArray(1,2).DigitalIdentifier.type, 'RRID');
        end
        
        function testFromAlphaNumStruct_InvalidInputFormat(testCase)
            alphaS.fullName = 'Bad Format Org';
            alphaS.DigitalIdentifier = {'not a struct'}; 
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, false), ...
                'ndi:validators:mustBeAlphaNumericStruct:InvalidFormat');
        end

        function testFromAlphaNumericStructMissingFieldRequired(testCase)
            alphaS.fullName = 'Missing ID Org'; 
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, true), 'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromAlphaNumericStructNestedMissingFieldRequired(testCase)
            alphaS.fullName = 'Nested Missing Field Org';
            alphaS.DigitalIdentifier = struct('type', 'RORID');
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, true), 'ndi:validators:mustHaveFields:MissingField');
        end

        function testFromAlphaNumericStructExtraField(testCase)
            alphaS.fullName = 'Extra Field Alpha Org';
            alphaS.DigitalIdentifier = struct('identifier', 'AS_ID_EXTRA', 'type', 'GRIDID');
            alphaS.anotherField = 'not allowed';
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, false), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
    end
end