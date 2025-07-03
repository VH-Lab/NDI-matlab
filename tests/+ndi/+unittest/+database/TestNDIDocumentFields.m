classdef TestNDIDocumentFields < matlab.unittest.TestCase
    % TestNDIDocumentFields - Unittest for the discovery of all NDI document field names.
    %
    % Description:
    %   This test verifies that the NDI framework can read all of its .json
    %   document definitions and extract a comprehensive list of all possible
    %   fully-qualified field names (e.g., 'base.id', 'element.name').

    methods (Test)
        function testFieldDiscoveryAndValidation(testCase)
            % This test executes the field discovery logic and validates the output.
            
            fprintf('Discovering all possible NDI document field names...\n');
            
            % --- 1. Execute the field discovery logic from the function ---
            
            % First, get the list of all JSON document file paths.
            json_docs = vlt.file.findfilegroups(ndi.common.PathConstants.DocumentFolder, {'.*\.json\>'});
            if iscell(ndi.common.PathConstants.CalcDoc)
                for i=1:numel(ndi.common.PathConstants.CalcDoc)
                    more_json_docs = vlt.file.findfilegroups(ndi.common.PathConstants.CalcDoc{i}, {'.*\.json\>'});
                    json_docs = cat(1, json_docs, more_json_docs);
                end
            end
            
            json_filenames = cell(numel(json_docs),1);
            for i=1:numel(json_docs)
                filepath = json_docs{i}{1};
                [~, filename, ~] = fileparts(filepath);
                if filename(1) ~= '.' % ignore hidden files
                    json_filenames{i} = filepath;
                end
            end

            % Now, execute the logic from all_doc_fields
            fn = {};
            for i=1:numel(json_filenames)
                t = vlt.file.textfile2char(json_filenames{i});
                s = jsondecode(t);
                s = rmfield(s,'document_class');
                fn_here = vlt.data.structfullfields(s);
                fn = cat(1, fn, fn_here);
            end
            
            fn = unique(fn);

            % --- 2. Verify the results with assertions ---

            fprintf('Found %d unique field names. Verifying...\n', numel(fn));

            % 2a. Verify the list is not empty.
            testCase.verifyNotEmpty(fn, 'The field discovery process returned an empty list.');
            
            % 2b. Verify the output is a cell array of strings.
            testCase.verifyClass(fn, 'cell', 'The list of field names should be a cell array.');
            testCase.verifyTrue(all(cellfun(@ischar, fn)), 'All elements in the list should be character strings.');

            % 2c. Verify that known, essential fields are present in the list.
            % This is a powerful check to ensure the core definitions are intact.
            essential_fields = {'base.id', 'base.name', 'base.session_id'};
            is_present = ismember(essential_fields, fn);
            
            testCase.verifyTrue(all(is_present), ...
                'One or more essential fields (e.g., base.id, base.name) were not found in the list.');
        end
    end
end