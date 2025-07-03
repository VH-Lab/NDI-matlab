function ndiDocuments = jsons2documents(jsonpath, options)
    %
    % [NDIDOCUMENTS] = JSONS2DOCUMENTS(JSONPATH)
    %
    % Load a set of NDI documents from a set of downloaded JSON files
    % at JSONPATH. Provides improved error reporting for JSON decoding issues,
    % treating unreadable or invalid files as errors. Execution halts on the first file error.
    % Excludes files starting with '._'.
    %
    arguments
        jsonpath (1,:) char {mustBeFolder}
        options.verbose logical = false
    end;

    verbose = options.verbose;
    d = dir([jsonpath filesep '*.json']);

    % Filter out files starting with '._' using logical indexing
    if verbose
        fprintf('Found %d potential JSON files.\n', numel(d));
    end

    % Extract filenames into a string array for easier logical indexing
    filenames = string({d.name});

    % Create a logical index for files NOT starting with '._'
    files_to_process_idx = ~startsWith(filenames, '._');

    files_to_process = d(files_to_process_idx);
    num_files_to_process = numel(files_to_process);

    if isempty(files_to_process)
        % As per requirements, no relevant files found is an error.
        error('NDI:jsons2documents:noRelevantJsonFiles', 'No relevant JSON files (excluding those starting with ._) found in the specified directory: %s', jsonpath);
    end

    if verbose
        fprintf('Processing %d relevant JSON files.\n', num_files_to_process);
    end

    % Initialize with the expected number of relevant documents for pre-allocation.
    % If an error occurs, the function will exit early.
    ndiDocuments = cell(1, num_files_to_process);
    session_id = '';
    doc_count = 0; % To keep track of successfully loaded documents

    for i = 1:num_files_to_process
        json_file_name = files_to_process(i).name;
        json_file_path = fullfile(jsonpath, json_file_name);

        if verbose
            fprintf('Processing file: %s\n', json_file_name);
        end

        try
            d_json = fileread(json_file_path);
            d_struct = jsondecode(d_json);

            % Check if the decoded structure has the expected 'document_properties' field
            if ~isfield(d_struct, 'document_properties')
                 % Error for invalid document structure
                 error('NDI:jsons2documents:missingDocumentProperties', ...
                    'Error processing file "%s": Missing "document_properties" field.', json_file_name);
            end

            if isfield(d_struct, 'id')
                d_struct = rmfield(d_struct, 'id'); % remove API field
            end

            doc_count = doc_count + 1;
            % Assign directly to the pre-allocated cell array
            ndiDocuments{doc_count} = ndi.document(d_struct.document_properties);

            if strcmp(ndiDocuments{doc_count}.doc_class, 'dataset_session_info')
                % Assuming there should only be one session_id per batch of documents
                if isempty(session_id)
                    session_id = ndiDocuments{doc_count}.document_properties.base.session_id;
                else
                    % Optional: Warn if multiple session_ids are found, as this might
                    % indicate an unexpected data structure but not necessarily a fatal error yet.
                    if verbose && ~strcmp(session_id, ndiDocuments{doc_count}.document_properties.base.session_id)
                         warning('NDI:jsons2documents:multipleSessionIds', ...
                            'Found multiple distinct session_ids. Using the first one encountered (%s).', session_id);
                    end
                end
            end

        catch ME
            % Catch errors during file reading or JSON decoding and re-throw as a specific error.
            % This halts execution as required.
            error('NDI:jsons2documents:fileProcessingError', ...
                'Error processing file "%s": %s', ...
                json_file_name, ME.message);
        end
    end

    % If the loop completes without errors, doc_count should equal num_files_to_process,
    % and ndiDocuments will be fully populated and correctly sized due to pre-allocation.
    % If an error occurred during the loop, the function would have already exited.

    % Final check for session_id among successfully loaded documents.
    % This error occurs only if the loop completed without file errors, but
    % no document of class 'dataset_session_info' was found.
    if isempty(session_id)
        error('NDI:jsons2documents:sessionIdNotFound', ...
            'Could not find session_id among the successfully processed documents.');
    end

    % The ndiDocuments array is already correctly sized due to pre-allocation
    % and the fact that any file error causes early exit.

end
