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
    % LEGACY NAME# SERIES ARE ENUMERATED, NOT COUNTED. file_list declares a
    % PATTERN ('tile.bin_#'); files.file_info records the concrete names
    % that were actually added, which is what current_file_list returns. An
    % earlier version walked NAME1, NAME2, ... and treated the first name
    % that was not there as the end of the series, because that gap was the
    % only termination signal a probing loop has.
    %
    % A sparse series defeats that, and sparse is the normal case: a gene
    % pyramid does not write a tile with no data in it, so its stored tiles
    % are 1, 4, 9, ... with holes between. The walk found the first hole and
    % called it the end. One real pyramid reached the cloud as 24 of its 450
    % tile files, with the upload reporting success -- the documents were
    % all there, so the dataset downloaded and opened, and failed at the
    % first tile read instead. See VH-Lab/NDI-matlab#956.
    %
    % Asking the document removes both the guessing and the terminator.
    %
    % NEW-STYLE SERIES (files.file_series) still need the separate pass
    % below: addFileSeries calls add_file once, for the series MANIFEST, so
    % file_info holds the manifest's name and not the members'. Those come
    % from the per-series record, and are one-based by DID's own rule
    % (VH-Lab/DID-matlab#183).

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
            % The names that were actually added, not the patterns that
            % could have been. A '#' in file_list never appears here.
            stored_names = database_documents{i}.current_file_list();

            for f = 1:numel(stored_names)
                this_filename = stored_names{f};

                [file_exists, full_file_path] = ...
                    ndi_dataset.database_existbinarydoc(ndi_document_id, this_filename);

                % A recorded name whose bytes are not resolvable is skipped
                % rather than fatal: the document is describing a file this
                % dataset cannot produce, which is the caller's problem to
                % notice, not a reason to abandon the other documents.
                if ~file_exists || isempty(full_file_path)
                    continue;
                end

                curr_idx = numel(file_manifest) + 1;
                [~, uid, ~] = fileparts(full_file_path);
                file_manifest(curr_idx).docid = ndi_document_id;
                file_manifest(curr_idx).uid = uid;
                file_manifest(curr_idx).name = this_filename;
                file_manifest(curr_idx).file_path = full_file_path;
                file_info = dir(full_file_path);
                file_manifest(curr_idx).bytes = file_info.bytes;
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
