classdef TestNDIDocumentJSON < matlab.unittest.TestCase
    % TestNDIDocumentJSON - A parameterized test to validate all NDI document JSON definitions.
    %
    % Description:
    %   This class discovers all '.json' document definition files within the NDI
    %   framework paths and runs an independent test for each one to ensure a
    %   blank ndi.document can be successfully created from it. This is a key
    %   validation test for the integrity of the NDI framework's data types.
    %

    properties (TestParameter)
        % This 'docType' property is a TestParameter. The test method below will
        % be run once for every value in this cell array. The values are
        % populated by the static helper method getJsonDocTypes().
        docType = ndi.unittest.database.TestNDIDocumentJSON.getJsonDocTypes();
    end

    methods (Test)
        function testSingleJsonDefinition(testCase, docType)
            % This test method is executed for each 'docType' parameter.
            % It verifies that ndi.document(docType) can be called without error
            % and that it returns an object of the correct class.
            
            % 1. Execute the constructor. If this throws an error, the test
            %    will automatically fail here, which is the desired behavior.
            my_doc = ndi.document(docType);

            % 2. Verify that the created object is of the correct class.
            %    This confirms the constructor returned the right thing.
            testCase.verifyClass(my_doc, 'ndi.document', ...
                ['Creating a document of type ''' docType ''' did not return an ndi.document object.']);
        end
    end
    
    methods (Static)
        function docTypes = getJsonDocTypes()
            % A helper function to find all unique .json document definition files
            % and return their base names (the document type strings).
            
            fprintf('Searching for NDI JSON document definitions...\n');
            
            % 1. Find all .json files in the primary and calculated document folders
            json_docs = vlt.file.findfilegroups(ndi.common.PathConstants.DocumentFolder, {'.*\.json\>'});
            
            if iscell(ndi.common.PathConstants.CalcDoc)
                for i = 1:numel(ndi.common.PathConstants.CalcDoc)
                    if isfolder(ndi.common.PathConstants.CalcDoc{i})
                        more_json_docs = vlt.file.findfilegroups(ndi.common.PathConstants.CalcDoc{i}, {'.*\.json\>'});
                        json_docs = cat(1, json_docs, more_json_docs);
                    end
                end
            end

            % 2. Process the list of full file paths into a clean list of type names
            docTypes = cell(numel(json_docs),1);
            for i = 1:numel(json_docs)
                % Each entry in json_docs is a cell array, get the first file path
                [~, filename, ~] = fileparts(json_docs{i}{1});
                
                % Ignore hidden files (like '.DS_Store') or swap files
                if filename(1) == '.'
                    continue;
                end
                
                docTypes{i} = filename;
            end
            
            % 3. Ensure the list is unique and sort it for consistent test order
            docTypes = unique(docTypes);
            
            fprintf('Found %d unique document types to test.\n', numel(docTypes));
        end
    end
end