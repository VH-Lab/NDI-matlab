% TestAuthorData.m
classdef TestAuthorData < matlab.unittest.TestCase
    %TESTAUTHDATA Unit tests for the AuthorData class.

    properties
        ClassName = 'ndi.gui.component.metadataEditor.class.AuthorData'
        OrgClassName = 'ndi.gui.component.metadataEditor.class.Organization'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            author = feval(testCase.ClassName);
            testCase.verifyClass(author, testCase.ClassName);
            testCase.verifyEqual(author.givenName, char.empty(1,0));
            testCase.verifyEqual(author.authorRole, {});
            % Corrected: Check that affiliation is an empty array of the correct class
            testCase.verifyClass(author.affiliation, testCase.OrgClassName);
            testCase.verifyTrue(isempty(author.affiliation));
        end

        function testPropertyAssignment(testCase)
            author = feval(testCase.ClassName);
            author.givenName = 'John';
            
            % Corrected: Assign an array of Organization objects
            org1 = feval(testCase.OrgClassName);
            org1.fullName = 'Org A';
            org2 = feval(testCase.OrgClassName);
            org2.fullName = 'Org B';
            author.affiliation = [org1, org2];
            
            testCase.verifyEqual(numel(author.affiliation), 2);
            testCase.verifyEqual(author.affiliation(2).fullName, 'Org B');
        end

        function testToStruct(testCase)
            author = feval(testCase.ClassName);
            author.givenName = 'Jane';
            
            org1 = feval(testCase.OrgClassName);
            org1.fullName = 'First Org';
            org2 = feval(testCase.OrgClassName);
            org2.fullName = 'Second Org';
            author.affiliation = [org1, org2];

            s = author.toStruct();
            testCase.verifyEqual(s.givenName, 'Jane');
            % Corrected: Check that the output field is a struct array
            testCase.verifyTrue(isstruct(s.affiliation));
            testCase.verifyEqual(numel(s.affiliation), 2);
            testCase.verifyEqual(s.affiliation(2).fullName, 'Second Org');
        end

        function testFromStructValid(testCase)
            % Corrected: s.affiliation is now a struct array
            s_org1 = struct('fullName', 'Org One', 'DigitalIdentifier', feval('ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier'), 'CellStrDelimiter', ', ');
            s_org2 = struct('fullName', 'Org Two', 'DigitalIdentifier', feval('ndi.gui.component.metadataEditor.class.OrganizationDigitalIdentifier'), 'CellStrDelimiter', ', ');

            s = struct(...
                'givenName', 'Sam', 'familyName', 'Smith', 'authorRole', {{'Data curation'}}, ...
                'contactInformation', feval('ndi.gui.component.metadataEditor.class.ContactInformation'), ...
                'digitalIdentifier', feval('ndi.gui.component.metadataEditor.class.AuthorDigitalIdentifier'), ...
                'affiliation', [s_org1, s_org2], ...
                'CellStrDelimiter', ', ' ...
            );

            author = ndi.util.StructSerializable.fromStruct(testCase.ClassName, s, false);
            testCase.verifyEqual(author.givenName, 'Sam');
            testCase.verifyEqual(numel(author.affiliation), 2);
            testCase.verifyEqual(author.affiliation(2).fullName, 'Org Two');
        end
        
        function testFromAlphaNumericStructValid(testCase)
            % Corrected: alphaS.affiliation is now a struct array
            alphaS_org1.fullName = 'NDI University';
            alphaS_org1.DigitalIdentifier = struct('identifier','','type','','CellStrDelimiter',',');
            alphaS_org1.CellStrDelimiter = ', ';
            
            alphaS_org2.fullName = 'The Brain Institute';
            alphaS_org2.DigitalIdentifier = struct('identifier','','type','','CellStrDelimiter',',');
            alphaS_org2.CellStrDelimiter = ', ';

            alphaS = struct(...
                'givenName', 'Jane', 'familyName', 'Doe', 'authorRole', 'Writing', ...
                'contactInformation', struct('email','jane.doe@example.com','CellStrDelimiter',','), ...
                'digitalIdentifier', struct('identifier','0000-0001','type','ORCID','CellStrDelimiter',','), ...
                'affiliation', [alphaS_org1, alphaS_org2], ...
                'CellStrDelimiter', ', ' ...
            );
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            author = f(alphaS);
            
            testCase.verifyEqual(author.givenName, 'Jane');
            testCase.verifyEqual(numel(author.affiliation), 2);
            testCase.verifyEqual(author.affiliation(2).fullName, 'The Brain Institute');
        end
    end
end