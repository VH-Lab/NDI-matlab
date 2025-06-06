classdef DocumentsTest < matlab.unittest.TestCase

    % If running this on cloud, need to set password and username for
    % testing as environment variables.

    properties (Constant)
        DatasetName = 'NDI_TEMPORARY_TEST';
    end

    properties
        DatasetID (1,1) string = missing % ID of dataset used for all tests
    end

    methods (TestClassSetup)
        function createDataset(testCase)
            datasetInfo = struct("name", testCase.DatasetName);
            [~, testCase.DatasetID] = ndi.cloud.api.datasets.create_dataset(datasetInfo); 
            testCase.addTeardown(@() deleteDataset(testCase.DatasetID))
        end
    end

    methods (Test)
        function verifyNoDocuments(testCase)
            [dataset, ~] = ndi.cloud.api.datasets.get_dataset(testCase.DatasetID);
            testCase.verifyEqual(...
                numel(dataset.documents), 0, ...
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
            
            testCase.verifyTrue(startsWith(document.name, "Test Document"), ...
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
                [response, test_document] = ndi.cloud.api.documents.get_document(testCase.DatasetID, documentId);
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
            testDocuments = createTestDocuments(numDocuments);

            % Upload documents
            ndi.cloud.upload.upload_document_collection(testCase.DatasetID, testDocuments)
            
            % Check if documents are uploaded:
            isFinished = false;
            timeOut = 10;
            t1 = tic;
            while ~isFinished && toc(t1) < timeOut
                [dataset, ~] = ndi.cloud.api.datasets.get_dataset(testCase.DatasetID);
                if numel(dataset.documents) == numDocuments
                    isFinished = true;
                else
                    pause(1)
                end
            end

            % Get IDs of uploaded documents
            testCase.verifyEqual(numel(dataset.documents), numDocuments)
            
            % Download all documents using bulk download
            downloadedDocuments = ...
                ndi.cloud.download.download_document_collection(testCase.DatasetID);
           
            for i = 1:numDocuments
                testCase.verifyEqual(testDocuments{i}, jsonencode(downloadedDocuments(i)))
            end

            % Download subset of documents using bulk download
            docIdx = [1,3,5];
            documentIds = dataset.documents;

            downloadedDocumentSubset = ...
                ndi.cloud.download.download_document_collection(testCase.DatasetID, documentIds(docIdx));
           
            for i = 1:numel(docIdx)
                testCase.verifyEqual(testDocuments{docIdx(i)}, jsonencode(downloadedDocumentSubset(i)))
            end

            % Clean up (delete documents)
            ndi.cloud.api.datasets.bulk_delete_documents(testCase.DatasetID, documentIds);

            % Download all documents after using bulk delete
            downloadedDocuments = ...
                ndi.cloud.download.download_document_collection(testCase.DatasetID);
            testCase.verifyEmpty(downloadedDocuments)
        end
    end

    methods % Non-test methods
        function documentId = addDocumentToDataset(testCase)
        % addDocumentToDataset - Create document and add it to the test dataset
            testDocument = createTestDocuments(1);
            
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
            testCase.verifyEqual(numel(dataset.documents), numDocuments, message)

            % list_dataset_documents api endpoint will return deleted
            % documents as well, so this is actually not a good way to
            % verify number of documents post deletion. 
            % Keeping the current code for future reference:
            % % [~, summary] = ndi.cloud.api.documents.list_dataset_documents(testCase.DatasetID);
            % % testCase.verifyEqual(numel(summary.documents), numDocuments, message)
        end
    end
end

function testDocuments = createTestDocuments(numDocuments)
    arguments
        numDocuments (1,1) uint32 = 1
    end
    testDocuments = cell(1, numDocuments);

    for i = 1:numDocuments
        randomName = sprintf("Test Document %s", char(randi([65 90], 1, 5)) );
        newTestDocument = struct("name", randomName);
        testDocuments{i} = jsonencode(newTestDocument);
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
