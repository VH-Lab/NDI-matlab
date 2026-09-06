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
    %
    % FILE SERIES. A new-style series (files.file_series) records its members
    % in a manifest rather than in file_list, and names them NAME_<i>, so the
    % file_list walk below never sees them -- it handles only the legacy
    % NAME# convention, whose members are NAME1, NAME2 and so on. Members are
    % therefore enumerated separately, from the per-series record, and
    % resolved by name through the manifest (VH-Lab/DID-matlab#183).
    %
    % Without this a series reaches the cloud as its manifest alone: a
    % document declaring N members, none of whose bytes were ever uploaded.
    % See VH-Lab/NDI-matlab#956.

    arguments
        ndi_dataset (1,1) ndi.dataset
        database_documents (1,:) cell
        verbose = false
    end

    num_documents = numel(database_documents);

    % Pre-allocate output struct arrays
    file_manifest = struct('name', {}, 'uid', {}, 'docid', {}, 'bytes', {}, 'file_path', {});

    % Explicitly open the database before scanning all the files to upload.
    % This process will run a large number of queries to the database, so
    % keep it open until finished.
    [db_cleanup_obj, ~] = ndi_dataset.open_database(); %#ok<ASGLU>

    for i = 1:num_documents

        if verbose && (mod(i, 1000)==0 || i == num_documents)
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
                        [~, uid, ~] = fileparts(full_file_path);
                        file_manifest(curr_idx).docid = ndi_document_id;
                        file_manifest(curr_idx).uid = uid;
                        file_manifest(curr_idx).name = this_filename;
                        file_manifest(curr_idx).file_path = full_file_path;
                        file_info = dir(full_file_path);
                        file_manifest(curr_idx).bytes = file_info.bytes;
                    end
                end
            end

            % Series members, which file_list does not name.
            seriesInfo = [];
            if isfield(database_documents{i}.document_properties.files, 'series_info')
                seriesInfo = database_documents{i}.document_properties.files.series_info;
            end

            for s = 1:numel(seriesInfo)
                slotCount = 0;
                if isfield(seriesInfo(s), 'count') && ~isempty(seriesInfo(s).count)
                    slotCount = seriesInfo(s).count;
                end
                series_name = seriesInfo(s).name;

                % Preallocated and trimmed rather than grown: a lightsheet
                % pyramid level is tens of thousands of members, and growing
                % the manifest one entry at a time is a reallocation each.
                member_entries = repmat(struct('name', '', 'uid', '', ...
                    'docid', '', 'bytes', 0, 'file_path', ''), 1, slotCount);
                member_count = 0;

                for m = 1:slotCount
                    member_name = sprintf('%s_%d', series_name, m);
                    [member_exists, member_path] = ...
                        ndi_dataset.database_existbinarydoc(ndi_document_id, member_name);
                    % An absent slot is normal: a sparse series is the case
                    % the mechanism exists for.
                    if ~member_exists || isempty(member_path)
                        continue;
                    end
                    [~, member_uid, ~] = fileparts(member_path);
                    member_info = dir(member_path);
                    member_count = member_count + 1;
                    member_entries(member_count) = struct( ...
                        'name', member_name, 'uid', member_uid, ...
                        'docid', ndi_document_id, 'bytes', member_info.bytes, ...
                        'file_path', member_path);
                end

                file_manifest = [file_manifest member_entries(1:member_count)]; %#ok<AGROW>
            end
        end
    end
end
