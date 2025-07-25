% testSubjectMaker.m
classdef testSubjectMaker < matlab.unittest.TestCase
%TESTSUBJECTMAKER Unit tests for the ndi.setup.NDIMaker.subjectMaker class.
%   Tests focus on getSubjectInfoFromTable, makeSubjectDocuments,
%   addSubjectsToSessions, and deleteSubjectDocs methods.

    properties
        Maker % Instance of the class under test
        TestDir % Root directory for temporary test sessions
        MockSessionCounter % Counter to ensure unique temp directory names per test method
    end

    methods (TestClassSetup)
        function createMakerAndTestDir(testCase)
            % Create an instance of the subjectMaker class once for all tests.
            testCase.Maker = ndi.setup.NDIMaker.subjectMaker();
            % Create a unique root directory for all temporary test directories
            testCase.TestDir = fullfile(tempdir, ['NDITest_' char(java.util.UUID.randomUUID().toString())]);
            if ~exist(testCase.TestDir, 'dir') % Ensure directory is created only if it doesn't exist
                mkdir(testCase.TestDir);
            end
            % Initialize MockSessionCounter
            testCase.MockSessionCounter = 0; 
            % Add a path to NDI if it's not already there - adjust as needed
            % This is a placeholder; ideally, NDI is already on the path for tests.
            % addpath(genpath(fullfile(userpath, 'NDI-matlab'))); % Example

            ndi.test.helper.initializeMksqliteNoOutput()
        end
    end

    methods (TestClassTeardown)
        function removeTestDir(testCase)
            % Remove the root temporary directory and its contents after all tests.
            if exist(testCase.TestDir, 'dir')
                rmdir(testCase.TestDir, 's');
            end
        end
    end

    methods (TestMethodSetup)
        function incrementMockSessionCounter(testCase)
            % Increment counter before each test method that might create sessions
            % to ensure unique directory names.
            testCase.MockSessionCounter = testCase.MockSessionCounter + 1;
        end
    end

    methods (Test)
        % --- Tests for getSubjectInfoFromTable ---

        function testGetSubjectInfo_BasicValid(testCase)
            dataTable = table(...
                {'SubjectA'; 'SubjectB'; 'SubjectA'}, ... 
                {'sess001'; 'sess002'; 'sess001'}, ...                 
                'VariableNames', {'subjectName', 'sessionID'});
            
            [subjectInfo, allNames] = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);

            testCase.verifyEqual(numel(subjectInfo.subjectName), 2, 'Diagnostic: Incorrect number of unique subjects.');
            testCase.verifyTrue(ismember('SubjectA', subjectInfo.subjectName), 'Diagnostic: SubjectA missing.');
            testCase.verifyTrue(ismember('SubjectB', subjectInfo.subjectName), 'Diagnostic: SubjectB missing.');
            
            idxA = strcmp(subjectInfo.subjectName, 'SubjectA');
            testCase.verifyEqual(subjectInfo.tableRowIndex(idxA), 1, 'Diagnostic: Incorrect tableRowIndex for SubjectA.');
            testCase.verifyEqual(subjectInfo.sessionID{idxA}, 'sess001', 'Diagnostic: Incorrect sessionID for SubjectA.');

            idxB = strcmp(subjectInfo.subjectName, 'SubjectB');
            testCase.verifyEqual(subjectInfo.tableRowIndex(idxB), 2, 'Diagnostic: Incorrect tableRowIndex for SubjectB.');
            testCase.verifyEqual(subjectInfo.sessionID{idxB}, 'sess002', 'Diagnostic: Incorrect sessionID for SubjectB.');
            
            testCase.verifyEqual(numel(allNames), height(dataTable), 'Diagnostic: allSubjectNamesFromTable length mismatch.');
            testCase.verifyEqual(allNames{3}, 'SubjectA', 'Diagnostic: allSubjectNamesFromTable content mismatch.');
        end

        function testGetSubjectInfo_NaNSubjectName(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectIDReturned'))
            
            dataTable = table(...
                {NaN; ''; 'SubjectC'; 'SubjectD'}, ...
                {'sess001'; 'sess002'; 'sess003'; 'sess004'}, ...
                'VariableNames', {'subjectName', 'sessionID'});
            
            [subjectInfo, ~] = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);
            
            testCase.verifyEqual(numel(subjectInfo.subjectName), 2, 'Diagnostic: NaN/empty names should be ignored.');
            testCase.verifyTrue(ismember('SubjectC', subjectInfo.subjectName));
            testCase.verifyTrue(ismember('SubjectD', subjectInfo.subjectName));
        end

        function testGetSubjectInfo_EmptyOrInvalidSessionID(testCase)
            dataTable = table(...
                {'SubE'; 'SubF'; 'SubG'; 'SubH'}, ...
                {'sess005'; ''; 'sess007'; NaN}, ... 
                'VariableNames', {'subjectName', 'sessionID'});
            
            [subjectInfo, ~] = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);

            testCase.verifyEqual(numel(subjectInfo.subjectName), 2, 'Diagnostic: Rows with empty/NaN sessionID should be ignored.');
            testCase.verifyTrue(ismember('SubE', subjectInfo.subjectName));
            testCase.verifyFalse(ismember('SubF', subjectInfo.subjectName), 'Diagnostic: SubF with empty sessionID should be excluded.');
            testCase.verifyTrue(ismember('SubG', subjectInfo.subjectName));
            testCase.verifyFalse(ismember('SubH', subjectInfo.subjectName), 'Diagnostic: SubH with NaN sessionID should be excluded.');
        end
        
        function testGetSubjectInfo_SessionIDAsCell(testCase)
            dataTable = table(...
                {'SubK'; 'SubL'; 'SubM'}, ...
                {{'sess001'}; {''}; {{'sess003'}}}, ... 
                'VariableNames', {'subjectName', 'sessionID'});
            
            [subjectInfo, ~] = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);
            
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

            [subjectInfo, ~] = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);

            testCase.verifyEqual(numel(subjectInfo.subjectName), 1, 'Diagnostic: Only ValidName2 should be included.');
            testCase.verifyTrue(ismember('ValidName2', subjectInfo.subjectName));
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
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('ndi:setup:NDIMaker:subjectMaker:InvalidSubjectIDReturned'))

            dataTable = table(...
                {NaN; ''; 'ValidNameButInvalidSession'}, ...
                {'sess001'; 'sess002'; ''}, ... 
                'VariableNames', {'subjectName', 'sessionID'});
            
            [subjectInfo, ~] = testCase.Maker.getSubjectInfoFromTable(dataTable, @ndi.unittest.setup.NDIMaker.testSubjectMaker.simpleSubjectInfoFun);
            testCase.verifyTrue(isstruct(subjectInfo));
            testCase.verifyTrue(isempty(subjectInfo.subjectName), 'Diagnostic: subjectName (unique) should be empty if all rows are invalid.');
            testCase.verifyTrue(isempty(subjectInfo.sessionID), 'Diagnostic: sessionID (unique) should be empty if all rows are invalid.');
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
            
            output = testCase.verifyWarning(@()testCase.Maker.makeSubjectDocuments(subjectInfo), ...
                'ndi:setup:NDIMaker:subjectMaker:EmptySubjectInfo');
            testCase.verifyTrue(isempty(output.subjectName));
            testCase.verifyTrue(isempty(output.documents));
        end

        function testMakeSubjectDocs_SessionIDLengthMismatchInSubjectInfo(testCase)
            subjectInfo.subjectName = {'SubZ'};
            subjectInfo.strain = {NaN};
            subjectInfo.species = {NaN};
            subjectInfo.biologicalSex = {NaN};
            subjectInfo.tableRowIndex = [1];
            subjectInfo.sessionID = {'s1'; 's2'}; 
            
            testCase.verifyError(@()testCase.Maker.makeSubjectDocuments(subjectInfo), ...
                'ndi:setup:NDIMaker:subjectMaker:SubjectSessionIDLengthMismatch'); 
        end
        
        function testMakeSubjectDocs_InvalidSessionIDEntryInSubjectInfo(testCase)
            subjectInfo.subjectName = {'SubValid'};
            subjectInfo.strain = {NaN};
            subjectInfo.species = {NaN};
            subjectInfo.biologicalSex = {NaN};
            subjectInfo.tableRowIndex = [1];
            subjectInfo.sessionID = {''}; 
            
            output = testCase.verifyWarning(...
                @() testCase.Maker.makeSubjectDocuments(subjectInfo), ...
                'ndi:setup:NDIMaker:subjectMaker:InvalidSessionIDFromSubjectInfo');
            testCase.verifyEqual(numel(output.documents), 1);
            testCase.verifyTrue(isempty(output.documents{1}), 'Diagnostic: Document cell should be empty for invalid sessionID in subjectInfo.');
        end

        % --- Tests for addSubjectsToSessions ---
        function testAddSubjectsToSessions_Basic(testCase)
            sessionDir1 = fullfile(testCase.TestDir, ['SessionAddTest1_' num2str(testCase.MockSessionCounter)]);
            if exist(sessionDir1, 'dir'), rmdir(sessionDir1,'s'); end 
            mkdir(sessionDir1);
            S1 = ndi.session.dir('TestAddRef1', sessionDir1); 

            sessionDir2 = fullfile(testCase.TestDir, ['SessionAddTest2_' num2str(testCase.MockSessionCounter)]);
            if exist(sessionDir2, 'dir'), rmdir(sessionDir2,'s'); end
            mkdir(sessionDir2);
            S2 = ndi.session.dir('TestAddRef2', sessionDir2); 

            subjectInfo.subjectName = {'TestSub1_S1'; 'TestSub2_S2'};
            subjectInfo.strain = {NaN; NaN};
            subjectInfo.species = {NaN; NaN};
            subjectInfo.biologicalSex = {NaN; NaN};
            subjectInfo.tableRowIndex = [1;2];
            subjectInfo.sessionID = {S1.id(); S2.id()}; 

            docOutput = testCase.Maker.makeSubjectDocuments(subjectInfo);
            documentsToAddSets = docOutput.documents; 

            sessionCellArray = {S1, S2}; % Pass as cell array
            added_status = testCase.Maker.addSubjectsToSessions(sessionCellArray, documentsToAddSets);
            
            testCase.verifyTrue(all(added_status), 'Diagnostic: All document sets should have been added.');

            querySub1_S1 = ndi.query('subject.local_identifier', 'exact_string', 'TestSub1_S1') & ...
                             ndi.query('','isa', 'subject');
            docsSub1_in_S1 = S1.database_search(querySub1_S1);
            testCase.verifyNumElements(docsSub1_in_S1, 1, 'Diagnostic: TestSub1_S1 not found or found multiple times in S1.');
            
            docsSub1_in_S2 = S2.database_search(querySub1_S1); 
            testCase.verifyEmpty(docsSub1_in_S2, 'Diagnostic: TestSub1_S1 should NOT be found in S2.');

            querySub2_S2 = ndi.query('subject.local_identifier', 'exact_string', 'TestSub2_S2') & ...
                             ndi.query('','isa', 'subject');
            docsSub2_in_S2 = S2.database_search(querySub2_S2);
            testCase.verifyNumElements(docsSub2_in_S2, 1, 'Diagnostic: TestSub2_S2 not found or found multiple times in S2.');

            docsSub2_in_S1 = S1.database_search(querySub2_S2); 
            testCase.verifyEmpty(docsSub2_in_S1, 'Diagnostic: TestSub2_S2 should NOT be found in S1.');
            
            rmdir(sessionDir1, 's');
            rmdir(sessionDir2, 's');
        end

        function testAddSubjectsToSessions_SessionNotFound(testCase)
            sessionDir = fullfile(testCase.TestDir, ['SessionNotFoundTest_' num2str(testCase.MockSessionCounter)]);
            if exist(sessionDir, 'dir'), rmdir(sessionDir,'s'); end
            mkdir(sessionDir);
            S_exists = ndi.session.dir('ExistingSessRef', sessionDir);

            docSetForMissingSession = {ndi.document('subject', ...
                'base.session_id', 'non_existent_session_id', ...
                'subject.local_identifier', 'SubMissingSession')};
            documentsToAddSets = {docSetForMissingSession};
            
            sessionCellArray = {S_exists}; % Pass as cell array

            added_status = testCase.verifyWarning(...
                @()testCase.Maker.addSubjectsToSessions(sessionCellArray, documentsToAddSets), ...
                'ndi:setup:NDIMaker:subjectMaker:SessionNotFoundForAdd');
            testCase.verifyFalse(added_status(1), 'Diagnostic: Status should be false if target session not found.');
            
            docsInExisting = S_exists.database_search(ndi.query('','isa','subject'));
            testCase.verifyEmpty(docsInExisting, 'Diagnostic: No documents should have been added to S_exists.');

            rmdir(sessionDir, 's');
        end


        % --- Tests for deleteSubjectDocs ---
        function testDeleteSubjectDocs_Basic(testCase)
            sessionDir = fullfile(testCase.TestDir, ['SessionDeleteTest_' num2str(testCase.MockSessionCounter)]);
            if exist(sessionDir, 'dir'), rmdir(sessionDir,'s'); end
            mkdir(sessionDir);
            S = ndi.session.dir('TestDeleteRef', sessionDir);

            doc1 = ndi.document('subject', 'base.session_id', S.id(), 'subject.local_identifier', 'ToDelete1');
            doc2 = ndi.document('subject', 'base.session_id', S.id(), 'subject.local_identifier', 'KeepIt');
            doc3 = ndi.document('subject', 'base.session_id', S.id(), 'subject.local_identifier', 'ToDelete2');
            S.database_add({doc1, doc2, doc3});

            sessionCellArray = {S}; % Pass as cell array
            localIdentifiersToDelete = {'ToDelete1', 'ToDelete2'};
            
            report = testCase.Maker.deleteSubjectDocs(sessionCellArray, localIdentifiersToDelete);

            testCase.verifyEqual(numel(report(1).docs_found_ids), 2, 'Diagnostic: Should find 2 documents to delete.');
            testCase.verifyEqual(numel(report(1).docs_deleted_ids), 2, 'Diagnostic: Should report 2 documents as deleted.');
            
            remainingDocs = S.database_search(ndi.query('','isa','subject'));
            testCase.verifyNumElements(remainingDocs, 1, 'Diagnostic: Incorrect number of documents remaining.');
            testCase.verifyEqual(remainingDocs{1}.document_properties.subject.local_identifier, 'KeepIt', 'Diagnostic: Incorrect document remaining.');
            
            rmdir(sessionDir, 's');
        end

        function testDeleteSubjectDocs_NoMatching(testCase)
            sessionDir = fullfile(testCase.TestDir, ['SessionDeleteNoMatchTest_' num2str(testCase.MockSessionCounter)]);
            if exist(sessionDir, 'dir'), rmdir(sessionDir,'s'); end
            mkdir(sessionDir);
            S = ndi.session.dir('TestDeleteNoMatchRef', sessionDir);
            doc1 = ndi.document('subject', 'base.session_id', S.id(), 'subject.local_identifier', 'KeepThisOne');
            S.database_add({doc1});
            
            sessionCellArray = {S}; % Pass as cell array
            localIdentifiersToDelete = {'IDThatDoesNotExist'};
            
            report = testCase.Maker.deleteSubjectDocs(sessionCellArray, localIdentifiersToDelete);
            
            testCase.verifyEmpty(report(1).docs_found_ids, 'Diagnostic: No documents should be found for deletion.');
            testCase.verifyEmpty(report(1).docs_deleted_ids, 'Diagnostic: No documents should be reported as deleted.');
            remainingDocs = S.database_search(ndi.query('','isa','subject'));
            testCase.verifyNumElements(remainingDocs, 1, 'Diagnostic: Document count should be unchanged.');
            
            rmdir(sessionDir, 's');
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
