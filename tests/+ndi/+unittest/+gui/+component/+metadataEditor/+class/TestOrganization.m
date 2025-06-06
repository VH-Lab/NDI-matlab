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
            % Also verify the inherited property has its default value
            testCase.verifyEqual(org.CellStrDelimiter, ', ');
        end

        function testToStruct(testCase)
            org = feval(testCase.OrgClassName);
            org.fullName = 'Test Org';
            org.DigitalIdentifier.identifier = 'ID001';
            
            s = org.toStruct();
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.fullName, 'Test Org');
            % Verify CellStrDelimiter is now included in the struct
            testCase.verifyEqual(s.CellStrDelimiter, ', ');
            testCase.verifyTrue(isstruct(s.DigitalIdentifier));
            testCase.verifyEqual(s.DigitalIdentifier.identifier, 'ID001');
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s.fullName = 'Struct Org';
            s.DigitalIdentifier = struct('identifier', 'ID_S1', 'type', 'RRID', 'CellStrDelimiter', ', ');
            s.CellStrDelimiter = ';';
            
            org = ndi.util.StructSerializable.fromStruct(testCase.OrgClassName, s, false);
            testCase.verifyClass(org, testCase.OrgClassName);
            testCase.verifyEqual(org.fullName, 'Struct Org');
            testCase.verifyEqual(org.DigitalIdentifier.identifier, 'ID_S1');
            testCase.verifyEqual(org.CellStrDelimiter, ';');
        end

        function testFromStructMissingFieldRequired(testCase)
            % Test for a missing 'fullName' by providing the others
            s.DigitalIdentifier = struct('identifier', 'ID_S2', 'type', 'RORID', 'CellStrDelimiter', ', ');
            s.CellStrDelimiter = ', ';
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.OrgClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromStructExtraField(testCase)
            s.fullName = 'Extra Field Org';
            s.DigitalIdentifier = struct('identifier', 'ID_S3', 'type', 'GRIDID', 'CellStrDelimiter', ', ');
            s.CellStrDelimiter = ', ';
            s.extraInfo = 'This should not be here';
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.OrgClassName, s, false), ...
                'ndi:validators:mustHaveOnlyFields:ExtraField');
        end

        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValidScalar(testCase)
            alphaS.fullName = 'AlphaScalar Org';
            alphaS.DigitalIdentifier = struct('identifier', 'AS_ID1', 'type', 'rorid', 'CellStrDelimiter', ';');
            alphaS.CellStrDelimiter = '|';
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            org = f(alphaS);
            
            testCase.verifyClass(org, testCase.OrgClassName);
            testCase.verifyEqual(org.fullName, 'AlphaScalar Org');
            testCase.verifyEqual(org.DigitalIdentifier.identifier, 'AS_ID1');
            testCase.verifyEqual(org.DigitalIdentifier.type, 'RORID');
            testCase.verifyEqual(org.DigitalIdentifier.CellStrDelimiter, ';');
            testCase.verifyEqual(org.CellStrDelimiter, '|');
        end
        
        function testFromAlphaNumericStructMissingFieldRequired(testCase)
            % Test missing 'fullName' by providing the other required fields
            alphaS.DigitalIdentifier = struct('identifier', '', 'type', '', 'CellStrDelimiter', ', ');
            alphaS.CellStrDelimiter = ', ';
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingField');
        end

        function testFromAlphaNumericStructExtraField(testCase)
            alphaS.fullName = 'Extra Field Alpha Org';
            alphaS.DigitalIdentifier = struct('identifier', 'AS_ID_EXTRA', 'type', 'GRIDID', 'CellStrDelimiter', ', ');
            alphaS.CellStrDelimiter = ', ';
            alphaS.anotherField = 'not allowed';
            
            f = str2func([testCase.OrgClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
    end
end