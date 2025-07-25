classdef TestNDIDocumentDiscovery < matlab.unittest.TestCase
    % TestNDIDocumentDiscovery - Unittest to verify the discovery of NDI document definition files.
    %
    % Description:
    %   This test class verifies that the NDI framework can correctly find all
    %   of its .json document definition files. It checks that the discovery
    %   process returns a non-empty list and that every file in the list
    %   actually exists and is a .json file.
    %

    methods (Test)
        function testDocumentDiscoveryAndValidation(testCase)
            % This test executes the file discovery logic and verifies the results.
            

            testCase.log(matlab.unittest.Verbosity.Verbose, ...
                'Searching for all NDI JSON document definition files...');
            
            % --- 1. Execute the file discovery logic from the original function ---
            
            % Find files in the primary document folder
            json_docs = vlt.file.findfilegroups(ndi.common.PathConstants.DocumentFolder, ...
                {'.*\.json\>'});
            
            % Find files in any additional calculated document folders
            if iscell(ndi.common.PathConstants.CalcDoc)
                for i=1:numel(ndi.common.PathConstants.CalcDoc)
                    more_json_docs = vlt.file.findfilegroups(ndi.common.PathConstants.CalcDoc{i}, ...
                        {'.*\.json\>'});
                    json_docs = cat(1, json_docs, more_json_docs);
                end
            end
            
            % Process the list to get full file paths, ignoring hidden files
            json_filenames = cell(numel(json_docs),1);
            for i=1:numel(json_docs)
                % Each entry in json_docs is a cell array of paths, get the first one
                filepath = json_docs{i}{1};
                [~, filename, ~] = fileparts(filepath);

                if filename(1) ~= '.' % ignore hidden files
                    json_filenames{i} = filepath;
                end
            end

            % --- 2. Verify the results with assertions ---
            testCase.log(matlab.unittest.Verbosity.Verbose, ...
                sprintf('Found %d files. Verifying results...', numel(json_filenames)));
            
            % 2a. Verify that the discovery process actually found some files.
            testCase.verifyNotEmpty(json_filenames, ...
                'The document discovery process returned an empty list of JSON files.');
            
            % 2b. Verify that the output is a cell array.
            testCase.verifyClass(json_filenames, 'cell', 'The output list should be a cell array.');

            % 2c. Loop through every discovered file and verify it.
            for i = 1:numel(json_filenames)
                current_file = json_filenames{i};
                
                % Verify the file path is a character string.
                testCase.verifyClass(current_file, 'char', ...
                    sprintf('List entry %d is not a character string.', i));
                
                % Verify that the file actually exists on the disk.
                % `exist(..., 'file')` returns 2 for files on the path.
                testCase.verifyEqual(exist(current_file, 'file'), 2, ...
                    sprintf('The discovered file path does not point to an existing file: %s', current_file));
                
                % Verify the file has the correct .json extension.
                [~, ~, ext] = fileparts(current_file);
                testCase.verifyEqual(ext, '.json', ...
                    sprintf('The discovered file does not have a .json extension: %s', current_file));
            end
        end
    end
end