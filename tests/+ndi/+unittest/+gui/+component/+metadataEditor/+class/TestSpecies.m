% TestSpecies.m
classdef TestSpecies < matlab.unittest.TestCase
    %TESTSPECIES Unit tests for the Species class.

    properties
        SpeciesClassName = 'ndi.gui.component.metadataEditor.class.Species'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            species = feval(testCase.SpeciesClassName);
            testCase.verifyClass(species, testCase.SpeciesClassName);
            testCase.verifyEqual(species.Name, char.empty(1,0));
            testCase.verifyEqual(species.Synonym, {});
            testCase.verifyEqual(species.OntologyIdentifier, char.empty(1,0));
            testCase.verifyEqual(species.uuid, char.empty(1,0));
            testCase.verifyEqual(species.Definition, char.empty(1,0));
            testCase.verifyEqual(species.Description, char.empty(1,0));
            testCase.verifyEqual(species.CellStrDelimiter, ', ');
        end

        function testPropertyAssignment(testCase)
            species = feval(testCase.SpeciesClassName);
            species.Name = 'Mus musculus';
            species.Synonym = {'House mouse', 'mouse'};
            species.OntologyIdentifier = 'NCBITaxon:10090';
            
            testCase.verifyEqual(species.Name, 'Mus musculus');
            testCase.verifyEqual(species.Synonym, {'House mouse', 'mouse'});
            testCase.verifyEqual(species.OntologyIdentifier, 'NCBITaxon:10090');
        end

        function testToStruct(testCase)
            species = feval(testCase.SpeciesClassName);
            species.Name = 'Homo sapiens';
            species.Synonym = {'Human', 'Man'};
            
            s = species.toStruct();
            testCase.verifyEqual(s.Name, 'Homo sapiens');
            testCase.verifyEqual(s.Synonym, {'Human', 'Man'});
        end

        function testToAlphaNumericStruct(testCase)
            species = feval(testCase.SpeciesClassName);
            species.Name = 'Danio rerio';
            species.Synonym = {'Zebrafish', 'zebra danio'};
            species.CellStrDelimiter = '|';

            alphaS = species.toAlphaNumericStruct();
            testCase.verifyEqual(alphaS.Name, 'Danio rerio');
            testCase.verifyEqual(alphaS.Synonym, 'Zebrafish|zebra danio');
            testCase.verifyTrue(ischar(alphaS.Synonym));
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s = struct(...
                'Name', 'Rattus norvegicus', ...
                'Synonym', {{'Rat', 'Norway rat'}}, ...
                'OntologyIdentifier', 'NCBITaxon:10116', ...
                'uuid', '', 'Definition', '', 'Description', '', ...
                'CellStrDelimiter', ', ' ...
            );
            
            species = ndi.util.StructSerializable.fromStruct(testCase.SpeciesClassName, s, false);
            testCase.verifyEqual(species.Name, 'Rattus norvegicus');
            testCase.verifyEqual(species.Synonym, {'Rat', 'Norway rat'});
        end

        function testFromStructMissingFieldRequired(testCase)
            s = struct('Name', 'Incomplete Species'); % Missing many required fields
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.SpeciesClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingFields');
        end
        
        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValid(testCase)
            alphaS = struct(...
                'Name', 'Gallus gallus', ...
                'Synonym', 'Chicken;Red junglefowl', ...
                'OntologyIdentifier', 'NCBITaxon:9031', ...
                'uuid', '', 'Definition', '', 'Description', '', ...
                'CellStrDelimiter', ';' ...
            );

            f = str2func([testCase.SpeciesClassName '.fromAlphaNumericStruct']);
            species = f(alphaS);

            testCase.verifyEqual(species.Name, 'Gallus gallus');
            testCase.verifyEqual(species.Synonym, {'Chicken', 'Red junglefowl'});
            testCase.verifyEqual(species.OntologyIdentifier, 'NCBITaxon:9031');
        end
        
        function testFromAlphaNumericStructEmptySynonym(testCase)
            alphaS = struct(...
                'Name', 'Empty Synonym Species', ...
                'Synonym', '', ... % Empty synonym string
                'OntologyIdentifier', '', 'uuid', '', 'Definition', '', 'Description', '', ...
                'CellStrDelimiter', ', ' ...
            );

            f = str2func([testCase.SpeciesClassName '.fromAlphaNumericStruct']);
            species = f(alphaS);
            
            testCase.verifyEqual(species.Synonym, {}, 'Empty synonym string should parse to an empty cell array.');
        end

        function testFromAlphaNumericStructMissingRequired(testCase)
            alphaS = struct('Name', 'Incomplete Species'); % Missing most required fields
            
            f = str2func([testCase.SpeciesClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingFields');
        end
        
        function testFromAlphaNumericStructExtraField(testCase)
            alphaS = struct(...
                'Name', 'Extra Species', 'Synonym', '', 'OntologyIdentifier', '', ...
                'uuid', '', 'Definition', '', 'Description', '', 'CellStrDelimiter', ',', ...
                'extraField', 'not allowed' ... % Extra field
            );
            
            f = str2func([testCase.SpeciesClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
    end
end