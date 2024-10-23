function upload_dataset_database(ndi_dataset, cloud_dataset_id, options)
    % UPLOAD_DATASET_DATABASE - Upload the complete database of a dataset
    %
    %   Syntax:
    %       ndi.cloud.upload_dataset_database(NDI_DATASET, CLOUD_DATASET_ID)
    %       uploads all the documents and associated binary files for a dataset
    %       to an NDI Cloud Dataset.
    %
    %   Input arguments:
    %       NDI_DATASET : string
    %           an ndi.dataset object
    %
    %       CLOUD_DATASET_ID : string
    %           an id for a dataset on NDI cloud to upload documents and files to
    %
    %   Options (Name - Value pairs)
    %       verbose : logical
    %           Whether to display status updates. Default is true
    %
    %       show_ui : logical
    %           Whether to display progress in a gui. Default is true


    arguments
        ndi_dataset (1,1) ndi.dataset
        cloud_dataset_id (1,1) string
        options.verbose = true
        options.show_ui = true
    end

    if options.verbose
        progress_trackers(1,3) = ndi.gui.component.internal.ProgressTracker();

        if options.show_ui
            ndi.cloud.ui.DatasetUploadMonitor(progress_trackers);
            pause(0.05)
            drawnow
        else
            arrayfun(@(pt) ndi.gui.component.CommandWindowProgressMonitor('ProgressTracker', pt), progress_trackers);
        end
    else
        progress_trackers(1,3) = missing;
    end

    % Define default/builtin disp
    disp = @(message) builtin('disp', message);


    % % Step 1 - Retrieve database documents
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if ~ismissing( progress_trackers(1) )
        disp = @(message) updateMessage(progress_trackers(1), message);
        progress_trackers(1).setTotalSteps(1)
    end

    if options.verbose; disp('Retrieving documents...'); end
    database_documents = ndi_dataset.database_search(ndi.query('','isa','base'));

    if ~ismissing( progress_trackers(1) )
        progress_trackers(1).setCompleted("Retrieved all documents.")
    end


    % % Step 2 - Upload documents
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if ~ismissing( progress_trackers(2) )
        disp = @(message) updateMessage(progress_trackers(2), message);
    end

    % Get document ids
    all_document_ids = cell(1, numel(database_documents));
    for i = 1:numel(database_documents)
        all_document_ids{i} = database_documents{i}.document_properties.base.id;
    end

    % If dataset exists from before, check if any have already been uploaded
    if options.verbose; disp('Checking if documents are already uploaded...'); end
    uploaded_document_ids = ndi.cloud.internal.get_uploaded_document_ids(cloud_dataset_id);

    % Start uploading documents:
    [~, keep_idx] = setdiff(all_document_ids, uploaded_document_ids);
    documents_for_upload = database_documents(keep_idx);

    if ~ismissing( progress_trackers(2) )
        progress_trackers(2).setTotalSteps( numel(documents_for_upload) );
        progress_trackers(2).TemplateMessage = sprintf('Uploading document {{CurrentStep}} of {{TotalSteps}} ({{PercentageComplete}}%%).');
    end

    num_documents = numel(documents_for_upload);
    for i = 1:num_documents
        if ~ismissing( progress_trackers(2) )
            progress_trackers(2).updateProgress(i)
        end
        json_document = did.datastructures.jsonencodenan(documents_for_upload{i}.document_properties);
        try
            [result] = ndi.cloud.api.documents.add_document(cloud_dataset_id, json_document);
        catch ME
            warning(ME.identifier, '%s', ME.message)
        end
    end

    if ~ismissing( progress_trackers(2) )
        progress_trackers(2).setCompleted("Uploaded all documents.")
    end

    % Get information about binary files:
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if ~ismissing( progress_trackers(3) )
        disp = @(message) updateMessage(progress_trackers(3), message);
    end

    if options.verbose; disp('Working on document''s binary files...'); end
    file_manifest = ...
        ndi.database.internal.list_binary_files(...
        ndi_dataset, database_documents, false); % verbose=false

    % Get file uids
    [~, all_file_uids, ~] = fileparts({file_manifest.file_path});
    [file_manifest(:).uid] = deal(all_file_uids{:});

    % Get uploaded file uids
    if options.verbose; disp('Checking if files are already uploaded...'); end

    uploaded_file_ids = ndi.cloud.internal.get_uploaded_file_ids(cloud_dataset_id);
    [~, keep_idx] = setdiff(all_file_uids, uploaded_file_ids, 'stable');
    file_manifest = file_manifest(keep_idx);

    % Start uploading document's binary files:
    auth_token = ndi.cloud.uilogin();

    % % % % Upload file function
    if options.verbose; disp( 'Uploading binary files...' ); end
    num_files = numel(file_manifest);

    if ~ismissing( progress_trackers(3) )
        progress_trackers(3).setTotalSteps( num_files );
        progress_trackers(3).TemplateMessage = ...
            sprintf('Uploading file {{CurrentStep}} of {{TotalSteps}} ({{PercentageComplete}}%%).');
    end

    for i = 1:num_files
        uid = file_manifest(i).uid;
        %upload_url = ndi.cloud.api.files.get_file_upload_url(cloud_dataset_id, uid);
        %uploadFile(file_manifest(i).file_path, upload_url, 'DisplayMode', 'None')

        if ~ismissing( progress_trackers(3) )
            progress_trackers(3).updateProgress(i)
        end

        try
            %fprintf('File size: %d KB. ', round(file_manifest(i).bytes/1024) )
            [~, ~, upload_url] = ndi.cloud.files.get_files(cloud_dataset_id, uid, auth_token);
            [status, response] = ndi.cloud.files.put_files(upload_url, file_manifest(i).file_path, auth_token);
        catch ME
            warning(ME.identifier, '%s', ME.message)
        end
    end
    if ~ismissing( progress_trackers(3) )
        progress_trackers(3).setCompleted("Uploaded all files.")
    end
end
