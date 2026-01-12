classdef testDatasetBuild < ndi.unittest.dataset.buildDataset
    % TESTDATASETBUILD - Test the setup and teardown of buildDataset
    %
    % This class inherits from buildDataset, so it will run setupDataset
    % before each test and teardownDataset after each test.

    methods (Test)
        function testSetup(testCase)
            % Verify that Dataset and Session are created and populated

            % Check Dataset existence
            testCase.verifyNotEmpty(testCase.Dataset, 'Dataset should be created');
            testCase.verifyTrue(isa(testCase.Dataset, 'ndi.dataset.dir'), 'Dataset should be ndi.dataset.dir');

            % Check Session existence
            testCase.verifyNotEmpty(testCase.Session, 'Session should be created');
            testCase.verifyTrue(isa(testCase.Session, 'ndi.session.dir'), 'Session should be ndi.session.dir');

            % Check that session is in dataset
            % add_ingested_session adds it to session_info and session_array

            % We can check session_list
            [ref_list, id_list] = testCase.Dataset.session_list();
            testCase.verifyTrue(any(strcmp(testCase.Session.id(), id_list)), 'Session ID should be in dataset session list');

            % Check documents in dataset
            % There should be 5 demoNDI documents
            q = ndi.query('','isa','demoNDI');
            docs = testCase.Dataset.database_search(q);

            testCase.verifyEqual(numel(docs), 5, 'Should find 5 demoNDI documents in the dataset');

            % Verify content
            for i=1:5
                docname = sprintf('doc_%d', i);

                % Find doc by name (we can query or search in docs)
                % Docs returned by database_search might be in any order
                found = false;
                for j=1:numel(docs)
                    if strcmp(docs{j}.document_properties.base.name, docname)
                        found = true;
                        % Check content
                        % Read the file associated with the doc
                        % We use database_openbinarydoc
                        fid = testCase.Dataset.database_openbinarydoc(docs{j}, 'filename1.ext');
                        % Read content
                        fseek(fid.fid, 0, 'bof'); % Reset pointer just in case
                        content = fread(fid.fid, inf, '*char')';
                        testCase.Dataset.database_closebinarydoc(fid);

                        testCase.verifyEqual(content, docname, ['Content of ' docname ' should match']);
                        break;
                    end
                end
                testCase.verifyTrue(found, ['Document ' docname ' should be found']);
            end
        end
    end
end
