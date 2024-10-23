function file_manifest = list_binary_files(ndi_dataset, database_documents, verbose)
    %LIST_BINARY_FILES - Scans a dataset for binary files of documents
    %
    % FILE_MANIFEST = ndi.database.internal.list_binary_files(NDI_DATASET, DATABASE_DOCUMENTS)
    %
    % Inputs:
    %   NDI_DATASET - an ndi.dataset object
    %   DATABASE_DOCUMENTS - documents returned by searching the dataset using database_search
    %
    % Outputs:
    %   FILE_MANIFEST - A structure with the following fields:
    %       'name' - The name of the file
    %       'file_path' - The full (absolute) pathname of the file
    %       'docid' - The document id that the file is associated with
    %       'bytes' - The size of the file in bytes

    arguments
        ndi_dataset (1,1) ndi.dataset
        database_documents (1,:) cell
        verbose = false
    end

    num_documents = numel(database_documents);

    % Pre-allocate output struct arrays
    file_manifest = struct('name', {}, 'docid', {}, 'bytes', {}, 'file_path', {});

    % Explicitly open the database before scanning all the files to upload.
    % This process will run a large number of queries to the database, so
    % keep it open until finished.
    [db_cleanup_obj, ~] = ndi_dataset.open_database(); %#ok<ASGLU>

    for i = 1:num_documents

        if verbose && (mod(i, 10)==0 || i == num_documents)
            fprintf('Working on document %d of %d\n', i, num_documents)
        end

        ndi_document_id = database_documents{i}.document_properties.base.id;

        if isfield(database_documents{i}.document_properties, 'files')
            for f = 1:numel(database_documents{i}.document_properties.files.file_list)
                file_name = database_documents{i}.document_properties.files.file_list{f};

                j = 1; is_finished = false;
                while ~is_finished % we could potentially read a series of files
                    if file_name(end)=='#' % this file is a series of files
                        this_filename = sprintf('%s%d', file_name(1:end-1), j);
                    else
                        this_filename = file_name;
                        is_finished = true; % only 1 file
                    end

                    [file_exists, full_file_path] = ...
                        ndi_dataset.database_existbinarydoc(ndi_document_id, this_filename);

                    if ~file_exists
                        is_finished = true;
                        full_file_path = '';
                    end

                    j = j + 1;
                    if ~isempty(full_file_path)
                        curr_idx = numel(file_manifest) + 1;
                        %[~, uid, ~] = fileparts(full_file_path);
                        file_manifest(curr_idx).docid = ndi_document_id;
                        %file_manifest(curr_idx).uid = uid;
                        file_manifest(curr_idx).name = this_filename;
                        file_manifest(curr_idx).file_path = full_file_path;
                        file_info = dir(full_file_path);
                        file_manifest(curr_idx).bytes = file_info.bytes;
                    end
                end
            end
        end
    end
end
