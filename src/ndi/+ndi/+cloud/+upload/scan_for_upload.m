function [doc_json_struct, doc_file_struct, total_size] = scan_for_upload(S, d, new, dataset_id)
    %SCAN_FOR_UPLOAD - Scans the session for documents and files to upload. Calculate the size of the files.
    %
    % [DOC_JSON_STRUCT,DOC_FILE_STRUCT] = ndi.cloud.upload.scan_for_upload(S, d, new, DATASET_ID)
    %
    % Inputs:
    %  S - an ndi.session object
    %  d - documents returned by searching the session using database_search
    %  NEW - 1 if this is a new dataset with empty documents and files, 0 otherwise
    %  DATASET_ID - The dataset id. dataset_id = '' if it is a new dataset
    %
    % Outputs:
    %  DOC_JSON_STRUCT - A structure with the following fields:
    %    'docid' - The document id
    %    'is_uploaded' - A flag indicating if the document is uploaded
    %  DOC_FILE_STRUCT - A structure with the following fields:
    %    'uid' - The uid of the file
    %    'name' - The name of the file
    %    'docid' - The document id that the file is associated with
    %    'bytes' - The size of the file in bytes
    %    'is_uploaded' - A flag indicating if the file is uploaded
    %  TOTAL_SIZE - The total size of the files to upload in KB

    verbose = 1;

    if verbose, disp(['Loading documents...']); end

    all_doc_ids = cell(1, numel(d));
    doc_json_struct = struct('docid',{},'is_uploaded', {});
    doc_file_struct = struct('name',{},'docid',{},'bytes',{},'is_uploaded', {});
    total_size = 0;

    % Explicitly open the database before scanning all the files to upload.
    % This process will run a large number of queries to the database, so keep
    % it open till finished.
    [db_cleanup_obj, ~] = S.open_database(); %#ok<ASGLU>

    for i=1:numel(d)
        if mod(i, 10)==0 || i == numel(d)
            fprintf('Working on document %d of %d\n', i, numel(d))
        end

        all_doc_ids{i} = d{i}.document_properties.base.id;
        doc_json_struct(i).docid = d{i}.document_properties.base.id;
        doc_json_struct(i).is_uploaded = false;
        ndi_doc_id = doc_json_struct(i).docid;
        if isfield(d{i}.document_properties, 'files')
            for f = 1:numel(d{i}.document_properties.files.file_list)
                file_name = d{i}.document_properties.files.file_list{f};

                j = 1;
                is_finished = false;
                while ~is_finished % we could potentially read a series of files
                    if file_name(end)=='#' % this file is a series of files
                        filename_here = sprintf('%s%d', file_name(1:end-1), j);
                    else
                        filename_here = file_name;
                        is_finished = true; % only 1 file
                    end

                    [file_exists, full_file_path] = S.database_existbinarydoc(ndi_doc_id, filename_here);

                    if ~file_exists
                        is_finished = true;
                        full_file_path = '';
                    end

                    j = j + 1;
                    if ~isempty(full_file_path)
                        curr_idx = numel(doc_file_struct)+1;
                        [~,uid,~] = fileparts(full_file_path);
                        doc_file_struct(curr_idx).uid = uid;
                        doc_file_struct(curr_idx).name = file_name;
                        doc_file_struct(curr_idx).docid = d{i}.document_properties.base.id;
                        file_info = dir(full_file_path);
                        doc_file_struct(curr_idx).bytes = file_info.bytes;
                        file_size = file_info.bytes / 1024;
                        total_size = file_size + total_size;
                        doc_file_struct(curr_idx).is_uploaded = false;
                    end
                end
            end
        end
    end
    clear db_cleanup_obj

    if (~new)
        [doc_resp, doc_summary] = ndi.cloud.api.documents.list_dataset_documents(dataset_id);

        [success, dataset] = ndi.cloud.api.datasets.getDataset(dataset_id);
        if ~success
            error(['Failed to get dataset: ' dataset.message]);
        end
        already_uploaded_docs = {};
        if numel(doc_summary.documents) > 0, already_uploaded_docs = {doc_summary.documents.ndiId}; end % prior version
        % if numel(doc_resp.documents) > 0, already_uploaded_docs = {doc_resp.documents.ndiId}; end;
        % [ids_left,document_indexes_to_upload] = setdiff(all_docs, already_uploaded_docs); % prior version
        [ids_left, document_indexes_to_upload] = setdiff(all_doc_ids, already_uploaded_docs);
        if numel(ids_left) == 0
            for i = 1:numel(doc_json_struct)
                doc_json_struct(i).is_uploaded = true;
            end
        else
            docid_upload = containers.Map(all_doc_ids(document_indexes_to_upload),  repmat({1}, 1, numel(document_indexes_to_upload)));
            for i = 1:numel(doc_json_struct)
                if (~isKey(docid_upload, doc_json_struct(i).docid))
                    doc_json_struct(i).is_uploaded = true;
                end
            end
        end

        % create a map contains dataset.files.uid as key and uploaded as value
        file_map = containers.Map;
        for i = 1:numel(dataset.files)
            file_map(dataset.files(i).uid) = dataset.files(i).uploaded;
        end
        for i = 1:numel(doc_file_struct)
            if (isKey(file_map, doc_file_struct(i).uid))
                doc_file_struct(i).is_uploaded = file_map(doc_file_struct(i).uid);
                if (doc_file_struct(i).is_uploaded)
                    total_size = total_size - doc_file_struct(i).bytes;
                end
            end
        end
    end
