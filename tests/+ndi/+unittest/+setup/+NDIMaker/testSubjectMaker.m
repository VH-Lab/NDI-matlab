% testSubjectMaker.m
classdef testSubjectMaker < matlab.unittest.TestCase
%TESTSUBJECTMAKER Unit tests for the ndi.setup.NDIMaker.subjectMaker class.
%   Tests focus on getSubjectInfoFromTable and makeSubjectDocuments methods.

    properties
        Maker % Instance of the class under test
    end

    methods (TestClassSetup)
        function createMaker(testCase)
            % Create an instance of the subjectMaker class once for all tests.
            testCase.Maker = ndi.setup.NDIMaker.subjectMaker();
        end
    end

    methods (Test)
        % --- Tests for getSubjectInfoFromTable ---

        function testGetSubjectInfo_BasicValid(testCase)
            dataTable = table(...
                {'SubjectA'; 'SubjectB'; 'SubjectA'}, ... 
                {'sess001'; 'sess002'; 'sess001'}, ...                 
                'VariableNames', {'subjectName', 'sessionID'});
            
            subjectInfo = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);

            testCase.verifyEqual(numel(subjectInfo.subjectName), 2, 'Diagnostic: Incorrect number of unique subjects.');
            testCase.verifyTrue(ismember('SubjectA', subjectInfo.subjectName), 'Diagnostic: SubjectA missing.');
            testCase.verifyTrue(ismember('SubjectB', subjectInfo.subjectName), 'Diagnostic: SubjectB missing.');
            
            idxA = strcmp(subjectInfo.subjectName, 'SubjectA');
            testCase.verifyEqual(subjectInfo.tableRowIndex(idxA), 1, 'Diagnostic: Incorrect tableRowIndex for SubjectA.');
            testCase.verifyEqual(subjectInfo.sessionID{idxA}, 'sess001', 'Diagnostic: Incorrect sessionID for SubjectA.');

            idxB = strcmp(subjectInfo.subjectName, 'SubjectB');
            testCase.verifyEqual(subjectInfo.tableRowIndex(idxB), 2, 'Diagnostic: Incorrect tableRowIndex for SubjectB.');
            testCase.verifyEqual(subjectInfo.sessionID{idxB}, 'sess002', 'Diagnostic: Incorrect sessionID for SubjectB.');
        end

        function testGetSubjectInfo_NaNSubjectName(testCase)
            dataTable = table(...
                {NaN; ''; 'SubjectC'; 'SubjectD'}, ...
                {'sess001'; 'sess002'; 'sess003'; 'sess004'}, ...
                'VariableNames', {'subjectName', 'sessionID'});
            
            subjectInfo = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);
            
            testCase.verifyEqual(numel(subjectInfo.subjectName), 2, 'Diagnostic: NaN/empty names should be ignored.');
            testCase.verifyTrue(ismember('SubjectC', subjectInfo.subjectName), 'Diagnostic: SubjectC missing after NaN/empty name test.');
            testCase.verifyTrue(ismember('SubjectD', subjectInfo.subjectName), 'Diagnostic: SubjectD missing after NaN/empty name test.');
        end

        function testGetSubjectInfo_EmptyOrInvalidSessionID(testCase)
            dataTable = table(...
                {'SubE'; 'SubF'; 'SubG'; 'SubH'}, ...
                {'sess005'; ''; 'sess007'; NaN}, ... 
                'VariableNames', {'subjectName', 'sessionID'});
            
            subjectInfo = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);

            testCase.verifyEqual(numel(subjectInfo.subjectName), 2, 'Diagnostic: Rows with empty/NaN sessionID should be ignored.');
            testCase.verifyTrue(ismember('SubE', subjectInfo.subjectName), 'Diagnostic: SubE missing.');
            testCase.verifyFalse(ismember('SubF', subjectInfo.subjectName), 'Diagnostic: SubF with empty sessionID should be excluded.');
            testCase.verifyTrue(ismember('SubG', subjectInfo.subjectName), 'Diagnostic: SubG missing.');
            testCase.verifyFalse(ismember('SubH', subjectInfo.subjectName), 'Diagnostic: SubH with NaN sessionID should be excluded.');
        end
        
        function testGetSubjectInfo_SessionIDAsCell(testCase)
            dataTable = table(...
                {'SubK'; 'SubL'; 'SubM'}, ...
                {{'sess001'}; {''}; {{'sess003'}}}, ... 
                'VariableNames', {'subjectName', 'sessionID'});
            
            subjectInfo = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);
            
            testCase.verifyEqual(numel(subjectInfo.subjectName), 2, 'Diagnostic: Incorrect handling of cell sessionID, wrong number of subjects found.');
            testCase.verifyTrue(ismember('SubK', subjectInfo.subjectName), 'Diagnostic: SubK missing with cell sessionID.');
            idxK = strcmp(subjectInfo.subjectName, 'SubK');
            testCase.verifyEqual(subjectInfo.sessionID{idxK}, 'sess001', 'Diagnostic: Incorrect sessionID for SubK.');
            
            testCase.verifyTrue(ismember('SubM', subjectInfo.subjectName), 'Diagnostic: SubM missing with nested cell sessionID.');
            idxM = strcmp(subjectInfo.subjectName, 'SubM');
            testCase.verifyEqual(subjectInfo.sessionID{idxM}, 'sess003', 'Diagnostic: Incorrect sessionID for SubM.');

            testCase.verifyFalse(ismember('SubL', subjectInfo.subjectName), 'Diagnostic: SubL with empty cell sessionID should be excluded.');
        end
        
        function testGetSubjectInfo_ValidNameInvalidSessionID(testCase)
            dataTable = table(...
                {'ValidName1'; 'ValidName2'; 'ValidName3'}, ...
                {''; 'valid_sess_id'; NaN}, ...
                'VariableNames', {'subjectName', 'sessionID'});

            subjectInfo = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);

            testCase.verifyEqual(numel(subjectInfo.subjectName), 1, 'Diagnostic: Only ValidName2 should be included.');
            testCase.verifyTrue(ismember('ValidName2', subjectInfo.subjectName), 'Diagnostic: ValidName2 missing.');
            idx = strcmp(subjectInfo.subjectName, 'ValidName2');
            testCase.verifyEqual(subjectInfo.sessionID{idx}, 'valid_sess_id', 'Diagnostic: Incorrect sessionID for ValidName2.');
        end


        function testGetSubjectInfo_EmptyTable(testCase)
            dataTable = table('Size', [0, 2], 'VariableTypes', {'cell', 'cell'}, ...
                'VariableNames', {'subjectName', 'sessionID'});
            
            testCase.verifyError(@()testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun), ...
                'MATLAB:validators:mustBeNonempty', ...
                'Diagnostic: Empty table should be caught by mustBeNonempty.');
        end

        function testGetSubjectInfo_AllInvalidRows(testCase)
            dataTable = table(...
                {NaN; ''; 'ValidNameButInvalidSession'}, ...
                {'sess001'; 'sess002'; ''}, ... 
                'VariableNames', {'subjectName', 'sessionID'});
            
            subjectInfo = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);
            testCase.verifyTrue(isstruct(subjectInfo));
            testCase.verifyTrue(isempty(subjectInfo.subjectName), 'Diagnostic: subjectName should be empty if all rows are invalid.');
            testCase.verifyTrue(isempty(subjectInfo.sessionID), 'Diagnostic: sessionID should be empty if all rows are invalid.');
        end

        % --- Tests for makeSubjectDocuments ---

        function testMakeSubjectDocs_Basic(testCase)
            subjectInfo.subjectName = {'SubX'; 'SubY'};
            subjectInfo.strain = {NaN; ndi.unittest.setup.NDIMaker.testSubjectMaker.createMockOpenMINDS('Strain')}; 
            subjectInfo.species = {ndi.unittest.setup.NDIMaker.testSubjectMaker.createMockOpenMINDS('Species'); NaN}; 
            subjectInfo.biologicalSex = {NaN; NaN};
            subjectInfo.tableRowIndex = [1; 2]; 
            subjectInfo.sessionID = {'session_abc'; 'session_def'}; 
            
            output = testCase.Maker.makeSubjectDocuments(subjectInfo); 

            testCase.verifyEqual(numel(output.subjectName), 2);
            testCase.verifyEqual(numel(output.documents), 2);
            
            testCase.verifyEqual(numel(output.documents{1}), 2, 'Diagnostic: SubX should have 2 documents.');
            mainDocX = output.documents{1}{1};
            speciesDocX = output.documents{1}{2};
            testCase.verifyEqual(mainDocX.document_properties.subject.local_identifier, 'SubX');
            testCase.verifyEqual(mainDocX.document_properties.base.session_id, 'session_abc');
            testCase.verifyEqual(speciesDocX.document_properties.base.session_id, 'session_abc', 'Diagnostic: Species doc session ID mismatch for SubX.');
            testCase.verifyNotEqual(speciesDocX.id(), mainDocX.id(), 'Diagnostic: Species doc ID should be different from main doc for SubX.');
            testCase.verifyNotEqual(speciesDocX.document_properties.document_class.class_name, 'subject', 'Diagnostic: Species document should not be of class_name "subject".');

            testCase.verifyEqual(numel(output.documents{2}), 2, 'Diagnostic: SubY should have 2 documents.');
            mainDocY = output.documents{2}{1};
            strainDocY = output.documents{2}{2};
            testCase.verifyEqual(mainDocY.document_properties.subject.local_identifier, 'SubY');
            testCase.verifyEqual(mainDocY.document_properties.base.session_id, 'session_def');
            testCase.verifyEqual(strainDocY.document_properties.base.session_id, 'session_def', 'Diagnostic: Strain doc session ID mismatch for SubY.');
            testCase.verifyNotEqual(strainDocY.id(), mainDocY.id(), 'Diagnostic: Strain doc ID should be different from main doc for SubY.');
            testCase.verifyNotEqual(strainDocY.document_properties.document_class.class_name, 'subject', 'Diagnostic: Strain document should not be of class_name "subject".');
        end

        function testMakeSubjectDocs_NoSubjects(testCase)
            subjectInfo.subjectName = {};
            subjectInfo.strain = {};
            subjectInfo.species = {};
            subjectInfo.biologicalSex = {};
            subjectInfo.tableRowIndex = [];
            subjectInfo.sessionID = {}; 
            
            testCase.verifyWarning(@()testCase.Maker.makeSubjectDocuments(subjectInfo), ...
                'ndi:setup:NDIMaker:subjectMaker:EmptySubjectInfo');
            output = testCase.Maker.makeSubjectDocuments(subjectInfo);
            testCase.verifyTrue(isempty(output.subjectName));
            testCase.verifyTrue(isempty(output.documents));
        end

        function testMakeSubjectDocs_SessionIDLengthMismatchInSubjectInfo(testCase)
            subjectInfo.subjectName = {'SubZ'};
            subjectInfo.strain = {NaN};
            subjectInfo.species = {NaN};
            subjectInfo.biologicalSex = {NaN};
            subjectInfo.tableRowIndex = [1];
            subjectInfo.sessionID = {'s1'; 's2'}; % Mismatch with subjectName length
            
            testCase.verifyError(@()testCase.Maker.makeSubjectDocuments(subjectInfo), ...
                'ndi:setup:NDIMaker:subjectMaker:SubjectSessionIDLengthMismatch'); 
        end
        
        function testMakeSubjectDocs_InvalidSessionIDEntryInSubjectInfo(testCase)
            subjectInfo.subjectName = {'SubValid'};
            subjectInfo.strain = {NaN};
            subjectInfo.species = {NaN};
            subjectInfo.biologicalSex = {NaN};
            subjectInfo.tableRowIndex = [1];
            subjectInfo.sessionID = {''}; % Invalid session ID in subjectInfo
            
            testCase.verifyWarning(@() testCase.Maker.makeSubjectDocuments(subjectInfo), ...
                                   'ndi:setup:NDIMaker:subjectMaker:InvalidSessionIDFromSubjectInfo');
            output = testCase.Maker.makeSubjectDocuments(subjectInfo);
            testCase.verifyEqual(numel(output.documents), 1);
            testCase.verifyTrue(isempty(output.documents{1}), 'Diagnostic: Document cell should be empty for invalid sessionID in subjectInfo.');
        end

    end % methods (Test)

    methods (Static)
        function [subjectId, strain, species, biologicalSex] = simpleSubjectInfoFun(tableRow)
            subjectId = NaN; 
            strain = NaN;
            species = NaN;
            biologicalSex = NaN;

            if ismember('subjectName', tableRow.Properties.VariableNames)
                val = tableRow.subjectName;
                if iscell(val) 
                    if ~isempty(val)
                        subjectId = val{1};
                    end
                else
                    subjectId = val; 
                end
                
                if isstring(subjectId) 
                    subjectId = char(subjectId);
                end
                if isnumeric(subjectId) && all(isnan(subjectId(:))) 
                    subjectId = NaN; 
                end
            end
        end

        function mockObj = createMockOpenMINDS(type)
            switch lower(type)
                case 'species'
                    mockObj = openminds.controlledterms.Species('name',['Mock' type]);
                case 'strain'
                    mockObj = openminds.core.research.Strain('name',['Mock' type]);
                case 'biologicalsex'
                    mockObj = openminds.controlledterms.BiologicalSex('name',['Mock' type]); 
                otherwise
                    error('Mock type %s not recognized for openMINDS object creation.', type);
            end
        end
    end % methods (Static)

end % classdef testSubjectMaker
