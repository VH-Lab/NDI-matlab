% TestFundingItem.m
classdef TestFundingItem < matlab.unittest.TestCase
    %TESTFUNDINGITEM Unit tests for the FundingItem class.

    properties
        ClassName = 'ndi.gui.component.metadataEditor.class.FundingItem'
        OrgClassName = 'ndi.gui.component.metadataEditor.class.Organization'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            item = feval(testCase.ClassName);
            testCase.verifyClass(item, testCase.ClassName);
            testCase.verifyEqual(item.Identifier, char.empty(1,0));
            testCase.verifyEqual(item.Title, char.empty(1,0));
            testCase.verifyClass(item.Organization, testCase.OrgClassName);
            testCase.verifyEqual(item.Organization.fullName, char.empty(1,0));
        end

        function testPropertyAssignment(testCase)
            item = feval(testCase.ClassName);
            item.Identifier = 'R01 NS012345';
            item.Title = 'Mechanisms of Neural Computation';
            
            org = feval(testCase.OrgClassName);
            org.fullName = 'National Institutes of Health';
            item.Organization = org;

            testCase.verifyEqual(item.Identifier, 'R01 NS012345');
            testCase.verifyEqual(item.Title, 'Mechanisms of Neural Computation');
            testCase.verifySameHandle(item.Organization, org);
            testCase.verifyEqual(item.Organization.fullName, 'National Institutes of Health');
        end

        function testToStruct(testCase)
            item = feval(testCase.ClassName);
            item.Title = 'Brain Initiative';
            item.Organization.fullName = 'NIH';
            
            s = item.toStruct();
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.Title, 'Brain Initiative');
            testCase.verifyTrue(isstruct(s.Organization));
            testCase.verifyEqual(s.Organization.fullName, 'NIH');
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s_org = struct(...
                'fullName', 'Wellcome Trust', ...
                'DigitalIdentifier', feval('ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier'), ...
                'CellStrDelimiter', ', ' ...
            );
            s = struct(...
                'Organization', s_org, ...
                'Identifier', 'WT102892', ...
                'Title', 'Investigator Award', ...
                'CellStrDelimiter', ', ' ...
            );
            
            item = ndi.util.StructSerializable.fromStruct(testCase.ClassName, s);
            testCase.verifyEqual(item.Identifier, 'WT102892');
            testCase.verifyEqual(item.Organization.fullName, 'Wellcome Trust');
        end

        function testFromStructMissingRequired(testCase)
            s = struct('Title', 'Incomplete Grant');
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.ClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingFields');
        end

        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValid(testCase)
            alphaS_org = struct(...
                'fullName', 'Simons Foundation', ...
                'DigitalIdentifier', struct('identifier', '10.13039/100000893', 'type', 'RORID', 'CellStrDelimiter', ', '), ...
                'CellStrDelimiter', ', ' ...
            );
            alphaS = struct(...
                'Organization', alphaS_org, ...
                'Identifier', '542943', ...
                'Title', 'SCGB', ...
                'CellStrDelimiter', ', ' ...
            );
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            item = f(alphaS);
            
            testCase.verifyEqual(item.Title, 'SCGB');
            testCase.verifyEqual(item.Organization.fullName, 'Simons Foundation');
            testCase.verifyEqual(item.Organization.DigitalIdentifier.identifier, '10.13039/100000893');
        end
        
        function testFromAlphaNumericStructArray(testCase)
            alphaS(1).Title = 'Grant A';
            alphaS(1).Identifier = 'A01';
            alphaS(1).Organization = struct('fullName','Org A','DigitalIdentifier',struct(),'CellStrDelimiter',',');
            alphaS(1).CellStrDelimiter = ',';
            
            alphaS(2).Title = 'Grant B';
            alphaS(2).Identifier = 'B02';
            alphaS(2).Organization = struct('fullName','Org B','DigitalIdentifier',struct(),'CellStrDelimiter',',');
            alphaS(2).CellStrDelimiter = ',';
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            items = f(alphaS);
            
            testCase.verifySize(items, [1 2]);
            testCase.verifyEqual(items(2).Title, 'Grant B');
            testCase.verifyEqual(items(2).Organization.fullName, 'Org B');
        end
    end
end