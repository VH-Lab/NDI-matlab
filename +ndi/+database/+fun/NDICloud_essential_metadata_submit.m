function [dataset, dataset_id] = NDICloud_essential_metadata_submit(email, password, location, dataIdentifier, datasetInformation)
    % NDICLOUD_ESSENTIAL_METADATA_SUBMIT - submit or update metadata in the cloud
    %
    % [DATASET, DATASET_ID] = ndi.database.fun.NDICloud_essential_metadata_submit(EMAIL, PASSWORD, LOCATION, DATAIDENTIFIER, DATASETINFORMATION)
    %
    % Inputs:
    %   EMAIL - a string with the email address
    %   PASSWORD - a string with the password
    %   LOCATION - a string. Either 'local' or 'cloud'.
    %   DATAIDENTIFIER - if LOCATION is 'local', then DATAIDENTIFIER is a ndi.session.dir
    %                    If LOCATION is 'cloud', then DATAIDENTIFIER is a string representing the dataset_id
    %   DATASETINFORMATION - a structure with metadata fields to submit

    [status, auth_token, organization_id] = ndi.cloud.api.auth.login(email, password);

    if strcmp(location, 'local')
        convertedDocs = ndi.database.metadata_app.convertFormDataToDocuments(datasetInformation, dataIdentifier.identifier);
        dataIdentifier = dataIdentifier.database_add(convertedDocs);
        size = ndi.database.fun.calculate_size_in_cloud(dataIdentifier);
        [status, response,dataset_id] = ndi.cloud.create_cloud_metadata_struct(auth_token, organization_id, datasetInformation, size);
        dataset = response;
        [b, msg] = ndi.database.fun.upload_to_NDI_cloud(dataIdentifier, email, password, dataset_id);
        if b
            disp(['Successfully uploaded to NDI cloud.']);
        else
            disp(['Error uploading to NDI cloud: ' msg]);
        end
    elseif strcmp(location, 'cloud')
        [status,dataset] = ndi.cloud.api.datasets.get_datasetId(dataIdentifier, auth_token);
        [deleted_size, session_id] = ndi.cloud.delete_cloud_openminds_doc(auth_token, dataIdentifier);
        convertedDocs = ndi.database.metadata_app.convertFormDataToDocuments(datasetInformation, session_id);
        added_size = ndi.cloud.calculate_document_size(convertedDocs);
        size = dataset.totalSize + added_size - deleted_size;
        size = 0;
        for i = 1: numel(convertedDocs)
            doc_str = jsonencode(convertedDocs{i});
            global ndi_globals;
            temp_dir = ndi_globals.path.temppath;
            ido_ = ndi.ido;
            rand_num = ido_.identifier;
            temp_filename = sprintf("file_%s.json", rand_num);
            path = fullfile(temp_dir,temp_filename);
            [status, response] = ndi.cloud.api.documents.post_documents(path, dataIdentifier, doc_str, auth_token);
            if ~status
                str = sprintf("Successfully updated %d documents NDI cloud", i);
                disp(str);
            else
                disp(['Error updating NDI cloud: ' response]);
            end
        end
        [status, dataset] = ndi.cloud.update_cloud_metadata_struct(dataIdentifier, auth_token, datasetInformation, size);
        dataset_id = dataIdentifier;
    else
        error(['Unknown location: ' location]);
    end
    
end    