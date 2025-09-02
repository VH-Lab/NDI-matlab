classdef DocumentsTest < matlab.unittest.TestCase

    % If running this on cloud, need to set password and username for
    % testing as environment variables.

    properties (Constant)
        DatasetName = 'NDI_TEMPORARY_TEST';
    end

    properties
        DatasetID (1,1) string = missing % ID of dataset used for all tests
    end

    methods (TestMethodSetup)
        % This now runs BEFORE EACH test method, creating a fresh dataset every time.
        function setupNewDataset(testCase)
            datasetInfo = struct("name", testCase.DatasetName);
            [~, testCase.DatasetID] = ndi.cloud.api.datasets.create_dataset(datasetInfo);
        end
    end

    methods (TestMethodTeardown)
        % This now runs AFTER EACH test method, deleting the dataset used by that test.
        function deleteDatasetAfterTest(testCase)
            % Check if DatasetID was set, in case setup failed
            if ~ismissing(testCase.DatasetID)
                deleteDataset(testCase.DatasetID);
            end
        end
    end

    methods (Test)
        function verifyNoDocuments(testCase)
            [dataset, ~] = ndi.cloud.api.datasets.get_dataset(testCase.DatasetID);
            if isfield(dataset,'documentCount')
                docCount = dataset.documentCount;
            else
                docCount = numel(dataset.documents);
            end            
            testCase.verifyEqual(...
                docCount, 0, ...
                'Expected 0 documents for new dataset')
        end

        function testCase = testAddDocument(testCase)
            documentId = testCase.addDocumentToDataset();
            testCase.addTeardown(@() testCase.deleteDocumentFromDataset(documentId))
            testCase.verifyNumDocumentsEqual(1, "after creating 1 document")
        end

        function testCase = testGetDocument(testCase)                
            documentId = testCase.addDocumentToDataset();
            testCase.addTeardown(@() testCase.deleteDocumentFromDataset(documentId))
            
            [~, document] = ...
                ndi.cloud.api.documents.get_document(...
                    testCase.DatasetID, documentId);
            
            testCase.verifyClass(document, 'struct', ...
                "Expected to get a document as a structure")
            
            testCase.verifyTrue(startsWith(document.base.name, "Test Document"), ...
                "Expected document name to start with 'Test Document'")
        end
        
        function testCase = testUpdateDocument(testCase)
            
            documentId = testCase.addDocumentToDataset();
            testCase.addTeardown(@() testCase.deleteDocumentFromDataset(documentId))

            [~, document] = ndi.cloud.api.documents.get_document(...
                    testCase.DatasetID, documentId);
            
            newName = 'Updated document name';
            document.name = newName;

            updatedDocumentJson = jsonencode(document);

            ndi.cloud.api.documents.update_document(...
                'temp', testCase.DatasetID, documentId, updatedDocumentJson);
            
            [~, updatedDocumentCloud] = ...
                ndi.cloud.api.documents.get_document(testCase.DatasetID, documentId);
    
            testCase.verifyEqual(updatedDocumentCloud.name, newName);
        end

        function testCase = testDeleteDocument(testCase)
            documentId = testCase.addDocumentToDataset();

            % Delete document
            ndi.cloud.api.documents.delete_document(testCase.DatasetID, documentId);   
            testCase.verifyNumDocumentsEqual(0, "post deletion")

            % try getting the document that was deleted. If no error is thrown, then the document was not deleted
            try
                %[response, test_document] = ndi.cloud.api.documents.get_document(testCase.DatasetID, documentId);
                ndi.cloud.api.documents.get_document(testCase.DatasetID, documentId);
                error('ndi.cloud.api.documents.get_document did not throw an error after delete_documents');
            catch
                % do nothing, this is the expected behavior
            end
        end

        function testBulkDeleteDocuments(testCase)
            numDocuments = 5;
            
            documentIds = cell(1, numDocuments);
                
            for i = 1:numDocuments
                documentIds{i} = testCase.addDocumentToDataset();
            end

            % Verify that document is uploaded
            testCase.verifyNumDocumentsEqual(numDocuments, "pre deletion")
            
            % Delete documents
            ndi.cloud.api.datasets.bulk_delete_documents(testCase.DatasetID, documentIds);

            % Verify that document is uploaded
            testCase.verifyNumDocumentsEqual(0, "post deletion")
        end

        function testDocumentBulkUploadAndDownload(testCase)
            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture)
            % Create test documents
            numDocuments = 5;
            testDocuments = createTestNDIDocuments(numDocuments);

            % Upload documents
            ndi.cloud.upload.upload_document_collection(testCase.DatasetID, testDocuments);
            
            % Check if documents are uploaded:
            pause(5)
            isFinished = false;
            timeOut = 100;
            t1 = tic;
            DocSummary.documents = [];
            while ~isFinished && toc(t1) < timeOut
                %disp(['Looking for documents'])
                [b, DocSummary] = ndi.cloud.api.documents.list_dataset_documents_all(testCase.DatasetID);
                if b&&(numel(DocSummary.documents) == numDocuments)
                    isFinished = true;                    
                else
                    %disp('Pausing again')
                    pause(1)
                end
            end
            
            % Count final uploaded documents
            testCase.verifyEqual(numel(DocSummary.documents), numDocuments, ...
                "All expected documents were not listed in the document summary for dataset " + ...
                testCase.DatasetID + ".");
            
            % Download all documents using bulk download
            downloadedDocuments = ...
                ndi.cloud.download.download_document_collection(testCase.DatasetID);
           
            for i = 1:numDocuments
                docHere = ndi.document('base');
                if numel(downloadedDocuments)>=i
                    docHere = downloadedDocuments{i};
                end
                testCase.verifyEqual(...
                    testDocuments{i}, ...
                    docHere,...
                    "Failed to find equality with uploaded test documents after downloading documents in dataset " + ...
                    testCase.DatasetID + ".");
            end

            if ~isempty(DocSummary.documents)
                documentIds = {DocSummary.documents.id};
                % Download subset of documents using bulk download
                docIdx = [1,3,5];
                [~, DocSummary] = ndi.cloud.api.documents.list_dataset_documents_all(testCase.DatasetID);
    
                downloadedDocumentSubset = ...
                    ndi.cloud.download.download_document_collection(testCase.DatasetID, documentIds(docIdx));
               
                for i = 1:numel(docIdx)
                    testCase.verifyEqual(...
                        downloadedDocumentSubset{i}, ...
                        testDocuments{docIdx(i)}, ...
                        "Failed to find equality with uploaded test documents after downloading a subset of documents in dataset "+ ...
                        testCase.DatasetID);
                end
            end

            if ~isempty(DocSummary.documents)
                documentIds = {DocSummary.documents.id};
                % Clean up (delete documents)
                ndi.cloud.api.datasets.bulk_delete_documents(testCase.DatasetID, documentIds);
            end

            pause(30);

            % Download all documents after using bulk delete
            downloadedDocuments = ...
                ndi.cloud.download.download_document_collection(testCase.DatasetID);
            testCase.verifyEmpty(downloadedDocuments,"There are still documents remaining in dataset " +testCase.DatasetID +" after bulk_delete request to remove them all (even after 30 second pause for processing).")
        end
    end

    methods % Non-test methods
        function documentId = addDocumentToDataset(testCase)
        % addDocumentToDataset - Create document and add it to the test dataset
            testDocument = createTestJSONDocuments(1);
            
            % Create a new document
            document = ndi.cloud.api.documents.add_document(testCase.DatasetID, testDocument);
            documentId = document.id;
        end

        function deleteDocumentFromDataset(testCase, documentId)
            ndi.cloud.api.documents.delete_document(testCase.DatasetID, documentId);
        end
        
        function verifyNumDocumentsEqual(testCase, numDocuments, messageSuffix)
        % verifyNumDocumentsEqual - Check that test dataset contains N documents
            message = sprintf("Expected %d document(s)", numDocuments);
            message = message + " " + messageSuffix + ".";

            % Verify expected number of documents 
            [dataset, ~] = ndi.cloud.api.datasets.get_dataset(testCase.DatasetID);
            if isfield(dataset,'documentCount')
                docCount = dataset.documentCount;
            else
                docCount = numel(dataset.documents);
            end
            testCase.verifyEqual(docCount, numDocuments, message)

            % list_dataset_documents api endpoint will return deleted
            % documents as well, so this is actually not a good way to
            % verify number of documents post deletion. 
            % Keeping the current code for future reference:
            % % [~, summary] = ndi.cloud.api.documents.list_dataset_documents(testCase.DatasetID);
            % % testCase.verifyEqual(numel(summary.documents), numDocuments, message)
        end
    end
end

function testDocuments = createTestJSONDocuments(numDocuments)
    arguments
        numDocuments (1,1) uint32 = 1
    end
    testDocuments = cell(1, numDocuments);

    for i = 1:numDocuments
        randomName = sprintf("Test Document %s", char(randi([65 90], 1, 5)) );
        newTestDocuments = ndi.document('base','base.name',randomName);
        testDocuments{i} = jsonencode(newTestDocuments.document_properties);
    end
    if numDocuments == 1
        testDocuments = testDocuments{1};
    end
end

function testDocuments = createTestNDIDocuments(numDocuments)
    arguments
        numDocuments (1,1) uint32 = 1
    end
    testDocuments = cell(1, numDocuments);

    for i = 1:numDocuments
        randomName = sprintf("Test Document %s", char(randi([65 90], 1, 5)) );
        newTestDocument = ndi.document('base','base.name',randomName);
        testDocuments{i} = newTestDocument;
    end
    if numDocuments == 1
        testDocuments = testDocuments{1};
    end
end



function deleteDataset(datasetId)
    try
        ndi.cloud.api.datasets.delete_dataset(datasetId);
    catch
        % Expecting fail
        for i = 1:numel(5)
            try % This should fail
                [~, ~] = ndi.cloud.api.datasets.get_dataset(datasetId);                    
            catch
                return % We want previous command to fail
            end
        end
    end
    % If we get here, dataset might not have been deleted
    warning('Dataset with id "%s" might not have been deleted', datasetId)
end
