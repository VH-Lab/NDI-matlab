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
            [status, ~, testCase.DatasetID] = ...
                ndi.cloud.api.datasets.create_dataset(datasetInfo); 
            assert(status == 0)
            testCase.addTeardown(@() deleteDataset(testCase.DatasetID))
        end
    end

    methods (Test)

        function verifyNoDocuments(testCase)
            [~, dataset, ~] = ndi.cloud.api.datasets.get_dataset(testCase.DatasetID);
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
            
            [~, ~, document] = ...
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

            [~, ~, document] = ndi.cloud.api.documents.get_document(...
                    testCase.DatasetID, documentId);
            
            newName = 'Updated document name';
            document.name = newName;

            updatedDocumentJson = jsonencode(document);

            [status, ~] = ndi.cloud.api.documents.update_document(...
                'temp', testCase.DatasetID, documentId, updatedDocumentJson);

            testCase.verifyEqual(status, 0, 'Expected api call to succeed')
            
            [~, ~, updatedDocumentCloud] = ...
                ndi.cloud.api.documents.get_document(testCase.DatasetID, documentId);
    
            testCase.verifyEqual(updatedDocumentCloud.name, newName);
        end

        function testCase = testDeleteDocument(testCase)
            
            documentId = testCase.addDocumentToDataset();

            % Delete document
            [status, ~] = ndi.cloud.api.documents.delete_document(...
                testCase.DatasetID, documentId);   
            testCase.verifyEqual(status, 0, 'Document delete failed')

            testCase.verifyNumDocumentsEqual(0, "post deletion")

            % try getting the document that was deleted. If no error is thrown, then the document was not deleted
            try
                [status, response, test_document] = ndi.cloud.api.documents.get_document(testCase.DatasetID, documentId);
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
            [status, ~] = ndi.cloud.api.datasets.bulk_delete_documents(testCase.DatasetID, documentIds);
            testCase.verifyEqual(status, 0, 'Bulk delete failed')

            % Verify that document is uploaded
            testCase.verifyNumDocumentsEqual(0, "post deletion")
        end
    end

    methods % Non-test methods
        function documentId = addDocumentToDataset(testCase)
        % addDocumentToDataset - Create document and add it to the test dataset
            testDocument = createTestDocument();
            
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
            [~, dataset, ~] = ndi.cloud.api.datasets.get_dataset(testCase.DatasetID);
            testCase.verifyEqual(numel(dataset.documents), numDocuments, message)

            [~, ~, summary] = ndi.cloud.api.documents.list_dataset_documents(testCase.DatasetID);
            testCase.verifyEqual(numel(summary.documents), numDocuments, message)
        end
    end
end

function testDocument = createTestDocument()
    randomName = sprintf("Test Document %s", char(randi([65 90], 1, 5)) );
    testDocument = struct("name", randomName);
    testDocument = jsonencode(testDocument);
end

function deleteDataset(datasetId)
    try
        [status, ~] = ndi.cloud.api.datasets.delete_dataset(datasetId);
    catch
        % Expecting fail

        for i = 1:numel(5)
            try % This should fail
                [~, ~, ~] = ndi.cloud.api.datasets.get_dataset(datasetId);                    
            catch
                return % We want previous command to fail
            end
        end
    end
    % If we get here, dataset might not have been deleted
    warning('Dataset with id "%s" might not have been deleted', datasetId)
end
