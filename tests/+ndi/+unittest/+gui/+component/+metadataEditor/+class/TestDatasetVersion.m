% TestDatasetVersion.m
classdef TestDatasetVersion < matlab.unittest.TestCase
    %TESTDATASETVERSION Unit tests for the DatasetVersion class.

    properties
        ClassName = 'ndi.gui.component.metadataEditor.class.DatasetVersion'
        LicenseClassName = 'ndi.gui.component.metadataEditor.class.License'
        FundingClassName = 'ndi.gui.component.metadataEditor.class.FundingItem'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            dv = feval(testCase.ClassName);
            testCase.verifyClass(dv, testCase.ClassName);
            testCase.verifyEqual(dv.ShortName, char.empty(1,0));
            testCase.verifyEqual(dv.DataType, cell.empty(1,0));
            testCase.verifyTrue(isnat(dv.ReleaseDate));
            testCase.verifyClass(dv.License, testCase.LicenseClassName);
            testCase.verifyClass(dv.Funding, testCase.FundingClassName);
            testCase.verifyTrue(isempty(dv.Funding));
        end

        function testPropertyAssignment(testCase)
            dv = feval(testCase.ClassName);
            dv.VersionIdentifier = '1.0.1';
            dv.ExperimentalApproach = {'electrophysiology'};
            dv.ReleaseDate = datetime(2025, 6, 6);
            
            testCase.verifyEqual(dv.VersionIdentifier, '1.0.1');
            testCase.verifyEqual(dv.ExperimentalApproach, {'electrophysiology'});
            testCase.verifyEqual(dv.ReleaseDate, datetime(2025, 6, 6));
        end

        function testToStruct(testCase)
            dv = feval(testCase.ClassName);
            dv.ShortName = 'Initial Release';
            dv.License.ShortName = 'CC BY 4.0';
            
            fundingItem = feval(testCase.FundingClassName);
            fundingItem.Identifier = 'R01MH123456';
            dv.Funding = [fundingItem];

            s = dv.toStruct();
            testCase.verifyEqual(s.ShortName, 'Initial Release');
            testCase.verifyEqual(s.License.ShortName, 'CC BY 4.0');
            testCase.verifyEqual(numel(s.Funding), 1);
            testCase.verifyEqual(s.Funding(1).Identifier, 'R01MH123456');
        end

        function testToAlphaNumericStruct(testCase)
            dv = feval(testCase.ClassName);
            dv.DataType = {'extracellular electrophysiology', 'behavioral data'};
            dv.ReleaseDate = datetime(2025, 1, 1, 'TimeZone', 'UTC');
            dv.CellStrDelimiter = '; ';

            alphaS = dv.toAlphaNumericStruct();
            testCase.verifyEqual(alphaS.DataType, 'extracellular electrophysiology; behavioral data');
            % datetime is serialized to ISO 8601 format by toAlphaNumericStruct
            testCase.verifyEqual(alphaS.ReleaseDate, '2025-01-01T00:00:00.000Z');
        end

        % --- Tests for static fromStruct & fromAlphaNumericStruct ---
        function testFromStructValid(testCase)
            s_funding = feval(testCase.FundingClassName).toStruct();
            s_funding.Identifier = 'F32DC098765';
            s = struct(...
                'Accessibility', 'public', 'DataType', {{'imaging'}}, 'DigitalIdentifier', '', ...
                'EthicsAssessment', 'approved', 'ExperimentalApproach', {{}}, ...
                'License', feval(testCase.LicenseClassName), 'ReleaseDate', datetime(), ...
                'ShortName', 'v1', 'Technique', {{}}, 'VersionIdentifier', '1.0', ...
                'VersionInnovation', 'initial data', 'Funding', [s_funding], ...
                'CellStrDelimiter', ', ' ...
            );
            
            dv = ndi.util.StructSerializable.fromStruct(testCase.ClassName, s);
            testCase.verifyEqual(dv.VersionIdentifier, '1.0');
            testCase.verifyEqual(numel(dv.Funding), 1);
            testCase.verifyEqual(dv.Funding(1).Identifier, 'F32DC098765');
        end
        
        function testFromAlphaNumericStructValid(testCase)
            alphaS_funding.Identifier = 'NINDS-R01'; alphaS_funding.Title = ''; alphaS_funding.CellStrDelimiter = ',';
            alphaS_funding.Organization = feval('ndi.gui.component.metadataEditor.class.Organization').toAlphaNumericStruct();

            alphaS = struct(...
                'Accessibility', 'controlled', 'DataType', 'calcium imaging;ephys', ...
                'DigitalIdentifier', 'doi:10.1234/data.1', 'EthicsAssessment', 'Not applicable', ...
                'ExperimentalApproach', '', 'License', feval(testCase.LicenseClassName).toAlphaNumericStruct(), ...
                'ReleaseDate', '2024-03-15T12:00:00.000Z', 'ShortName', 'v2', ...
                'Technique', '2-photon;patch-clamp', 'VersionIdentifier', '2.0', ...
                'VersionInnovation', 'added new analysis', 'Funding', [alphaS_funding], ...
                'CellStrDelimiter', ';' ...
            );
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            dv = f(alphaS);
            
            testCase.verifyEqual(dv.DataType, {'calcium imaging', 'ephys'});
            expectedDate = datetime(2024, 3, 15, 12, 0, 0, 'TimeZone', 'UTC');
            testCase.verifyEqual(dv.ReleaseDate, expectedDate);
            testCase.verifyEqual(dv.Funding(1).Identifier, 'NINDS-R01');
        end

        function testFromAlphaNumericStructMissingRequired(testCase)
            alphaS = struct('ShortName', 'Incomplete'); % Missing most required fields
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingFields');
        end
    end
end