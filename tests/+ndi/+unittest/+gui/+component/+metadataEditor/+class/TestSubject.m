% TestSubject.m
classdef TestSubject < matlab.unittest.TestCase
    %TESTSUBJECT Unit tests for the Subject class.

    properties
        ClassName = 'ndi.gui.component.metadataEditor.class.Subject'
        SpeciesClassName = 'ndi.gui.component.metadataEditor.class.Species'
        StrainClassName = 'ndi.gui.component.metadataEditor.class.Strain'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            subject = feval(testCase.ClassName);
            testCase.verifyClass(subject, testCase.ClassName);
            testCase.verifyEqual(subject.SubjectName, char.empty(1,0));
            testCase.verifyEqual(subject.BiologicalSexList, cell.empty(1,0));
            testCase.verifyClass(subject.SpeciesList, testCase.SpeciesClassName);
            testCase.verifyTrue(isempty(subject.SpeciesList));
            testCase.verifyClass(subject.StrainList, testCase.StrainClassName);
            testCase.verifyTrue(isempty(subject.StrainList));
            testCase.verifyEqual(subject.SessionIdentifier, char.empty(1,0));
            testCase.verifyEqual(subject.CellStrDelimiter, ', ');
        end

        function testPropertyAssignment(testCase)
            subject = feval(testCase.ClassName);
            
            subject.SubjectName = 'Subject01';
            testCase.verifyEqual(subject.SubjectName, 'Subject01');
            
            subject.BiologicalSexList = {'male', 'female'};
            testCase.verifyEqual(subject.BiologicalSexList, {'male', 'female'});

            newSpecies = feval(testCase.SpeciesClassName);
            newSpecies.Name = 'Mus musculus';
            subject.SpeciesList = [newSpecies];
            testCase.verifyEqual(numel(subject.SpeciesList), 1);
            testCase.verifyEqual(subject.SpeciesList(1).Name, 'Mus musculus');
        end

        function testToStruct(testCase)
            subject = feval(testCase.ClassName);
            subject.SubjectName = 'S1';
            species1 = feval(testCase.SpeciesClassName);
            species1.Name = 'Mus musculus';
            subject.SpeciesList = [species1];

            s = subject.toStruct();
            testCase.verifyEqual(s.SubjectName, 'S1');
            testCase.verifyTrue(isstruct(s.SpeciesList));
            testCase.verifyEqual(s.SpeciesList(1).Name, 'Mus musculus');
        end

        function testToAlphaNumericStruct(testCase)
            subject = feval(testCase.ClassName);
            subject.BiologicalSexList = {'female', 'not specified'};
            subject.CellStrDelimiter = '|';
            
            alphaS = subject.toAlphaNumericStruct();
            testCase.verifyEqual(alphaS.BiologicalSexList, 'female|not specified');
            testCase.verifyTrue(ischar(alphaS.BiologicalSexList));
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s_species.Name = 'Mus musculus';
            s_species.Synonym = {}; s_species.OntologyIdentifier = ''; s_species.uuid = ''; s_species.Definition = ''; s_species.Description = ''; s_species.CellStrDelimiter = ', ';
            
            s = struct(...
                'SubjectName', 'Subj1', ...
                'BiologicalSexList', {{'male'}}, ...
                'SpeciesList', s_species, ... 
                'StrainList', feval(testCase.StrainClassName).empty(1,0), ...
                'SessionIdentifier', 'Sess01', ...
                'CellStrDelimiter', ';' ...
            );
            
            subject = ndi.util.StructSerializable.fromStruct(testCase.ClassName, s, false);
            testCase.verifyEqual(subject.SubjectName, 'Subj1');
            testCase.verifyEqual(subject.SpeciesList(1).Name, 'Mus musculus');
            testCase.verifyEqual(subject.CellStrDelimiter, ';');
        end
        
        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValid(testCase)
            alphaS_species1.Name = 'Mus musculus';
            alphaS_species1.Synonym = ''; alphaS_species1.OntologyIdentifier = ''; alphaS_species1.uuid = ''; alphaS_species1.Definition = ''; alphaS_species1.Description = ''; alphaS_species1.CellStrDelimiter = ', ';
            
            alphaS = struct(...
                'SubjectName', 'Subj_A1', ...
                'BiologicalSexList', 'not specified', ...
                'SpeciesList', [alphaS_species1], ...
                'StrainList', [], ...
                'SessionIdentifier', 'Sess_A1', ...
                'CellStrDelimiter', ', ' ...
            );
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            subject = f(alphaS);
            
            testCase.verifyEqual(subject.SubjectName, 'Subj_A1');
            testCase.verifyEqual(subject.BiologicalSexList, {'not specified'});
            testCase.verifyEqual(subject.SpeciesList(1).Name, 'Mus musculus');
            testCase.verifyTrue(isempty(subject.StrainList));
        end
        
        function testFromAlphaNumericStructMissingRequired(testCase)
            alphaS = struct('SubjectName', 'Incomplete');
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingFields');
        end
    end
end