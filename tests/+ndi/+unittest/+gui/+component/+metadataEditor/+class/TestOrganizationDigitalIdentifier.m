% TestOrganizationDigitalIdentifier.m
classdef TestOrganizationDigitalIdentifier < matlab.unittest.TestCase
    %TESTORGANIZATIONDIGITALIDENTIFIER Unit tests for the OrganizationDigitalIdentifier class.

    properties
        OrgIdClassName = 'ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            orgId = feval(testCase.OrgIdClassName);
            testCase.verifyClass(orgId, testCase.OrgIdClassName);
            testCase.verifyEqual(orgId.identifier, char.empty(1,0));
            testCase.verifyEqual(orgId.type, char.empty(1,0));
        end

        function testPropertyAssignmentValid(testCase)
            orgId = feval(testCase.OrgIdClassName);
            orgId.identifier = '12345';
            testCase.verifyEqual(orgId.identifier, '12345');
            orgId.type = 'RORID';
            testCase.verifyEqual(orgId.type, 'RORID');
        end

        function testPropertyValidationTypeInvalid(testCase)
            orgId = feval(testCase.OrgIdClassName);
            try
                orgId.type = 'INVALIDTYPE';
                testCase.fail('An error was expected but not thrown when assigning an invalid value to type.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validators:mustBeMember');
            end
        end
        
        function testPropertyValidationIdentifierNotChar(testCase)
            orgId = feval(testCase.OrgIdClassName);
            % Corrected: Use a struct, which cannot be converted to char, 
            % to reliably trigger the property validation error.
            try
                orgId.identifier = struct('a', 1); 
                testCase.fail('An error was expected but not thrown for non-char assignment.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validation:UnableToConvert');
            end
        end

        function testToStruct(testCase)
            orgId = feval(testCase.OrgIdClassName);
            orgId.identifier = 'id1';
            orgId.type = 'RORID';
            s = orgId.toStruct();
            
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.identifier, 'id1');
            testCase.verifyEqual(s.type, 'RORID');
        end

        function testToAlphaNumericStruct(testCase)
            orgId = feval(testCase.OrgIdClassName);
            orgId.identifier = 'id2';
            orgId.type = 'GRIDID';
            alphaS = orgId.toAlphaNumericStruct();

            testCase.verifyTrue(isstruct(alphaS));
            testCase.verifyEqual(alphaS.identifier, 'id2');
            testCase.verifyEqual(alphaS.type, 'GRIDID');
            [isValid, ~] = ndi.util.isAlphaNumericStruct(alphaS);
            testCase.verifyTrue(isValid);
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s.identifier = 'structId';
            s.type = 'RRID';
            orgId = ndi.util.StructSerializable.fromStruct(testCase.OrgIdClassName, s, false);
            testCase.verifyClass(orgId, testCase.OrgIdClassName);
            testCase.verifyEqual(orgId.identifier, s.identifier);
            testCase.verifyEqual(orgId.type, s.type);
        end

        function testFromStructMissingFieldsOptional(testCase)
            s = struct('type', 'GRIDID');
            orgId = ndi.util.StructSerializable.fromStruct(testCase.OrgIdClassName, s, false);
            testCase.verifyClass(orgId, testCase.OrgIdClassName);
            testCase.verifyEqual(orgId.identifier, char.empty(1,0));
            testCase.verifyEqual(orgId.type, 'GRIDID');
        end

        function testFromStructMissingIdentifierRequired(testCase)
            s.type = 'RORID'; 
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.OrgIdClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end

        function testFromStructMissingTypeRequired(testCase)
            s.identifier = 'idOnly'; 
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.OrgIdClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromStructExtraField(testCase)
            s.identifier = 'id';
            s.type = 'GRIDID';
            s.extra = 'unexpected';
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.OrgIdClassName, s, false), ...
                'ndi:validators:mustHaveOnlyFields:ExtraField');
        end

        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValidScalar(testCase)
            alphaS.identifier = 'alphaId1';
            alphaS.type = 'rorid'; 
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            orgId = f(alphaS, false);
            testCase.verifyClass(orgId, testCase.OrgIdClassName);
            testCase.verifyEqual(orgId.identifier, alphaS.identifier);
            testCase.verifyEqual(orgId.type, 'RORID');
        end

        function testFromAlphaNumericStructValidArray(testCase)
            alphaS(1,1).identifier = 'id_A'; alphaS(1,1).type = 'gridid';
            alphaS(1,2).identifier = 'id_B'; alphaS(1,2).type = 'RRID';
            
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            orgIdArray = f(alphaS, false);
            testCase.verifyClass(orgIdArray, testCase.OrgIdClassName);
            testCase.verifySize(orgIdArray, [1 2]);
            
            testCase.verifyEqual(orgIdArray(1,1).identifier, 'id_A');
            testCase.verifyEqual(orgIdArray(1,1).type, 'GRIDID');
            testCase.verifyEqual(orgIdArray(1,2).identifier, 'id_B');
            testCase.verifyEqual(orgIdArray(1,2).type, 'RRID');
        end
        
        function testFromAlphaNumStruct_InvalidInputFormat(testCase)
            alphaS.identifier = 'id';
            alphaS.type = { 'RORID' };
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, false), ...
                'ndi:validators:mustBeAlphaNumericStruct:InvalidFormat');
        end

        function testFromAlphaNumericStructMissingFieldsOptional(testCase)
            alphaS = struct();
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            orgId = f(alphaS, false);
            testCase.verifyEqual(orgId.identifier, char.empty(1,0));
            testCase.verifyEqual(orgId.type, char.empty(1,0));
        end

        function testFromAlphaNumericStructMissingIdentifierRequired(testCase)
            alphaS.type = 'RORID';
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, true), 'ndi:validators:mustHaveFields:MissingField');
        end

        function testFromAlphaNumericStructMissingTypeRequired(testCase)
            alphaS.identifier = 'idOnly';
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, true), 'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromAlphaNumericStructTypeValidation(testCase)
            alphaS.identifier = 'id';
            alphaS.type = 'INVALID_TYPE';
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, false), 'MATLAB:validators:mustBeMember');
        end

        function testFromAlphaNumericStructExtraField(testCase)
            alphaS.identifier = 'id';
            alphaS.type = 'RRID';
            alphaS.extraData = 123;
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, false), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
        
        function testFromAlphaNumericStructEmptyInputArray(testCase)
            alphaS = struct('identifier', {}, 'type', {});
            f = str2func([testCase.OrgIdClassName '.fromAlphaNumericStruct']);
            orgIdArray = f(alphaS, false);
            testCase.verifyClass(orgIdArray, testCase.OrgIdClassName);
            testCase.verifyTrue(isempty(orgIdArray));
        end
    end
end