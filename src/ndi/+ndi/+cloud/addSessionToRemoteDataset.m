function [success, message] = addSessionToRemoteDataset(cloudDatasetId, S, options)
% addSessionToRemoteDataset - Add a session to a remote dataset
%
% [SUCCESS, MESSAGE] = ndi.cloud.addSessionToRemoteDataset(CLOUDDATASETID, S, ...)
%
% Adds an ndi.session object S to a remote dataset specified by CLOUDDATASETID.
%
% Inputs:
%   CLOUDDATASETID - The unique identifier of the remote dataset.
%   S - The ndi.session object to add.
%
% Options:
%   'ndiDataset' - (Optional) A local ndi.dataset object. If provided, the function
%                  will sync the local dataset with the remote version after adding
%                  the session.
%
% Output:
%   SUCCESS - Boolean indicating success.
%   MESSAGE - Error message if any.
%

arguments
    cloudDatasetId (1,1) string
    S (1,1) {mustBeA(S, 'ndi.session')}
    options.ndiDataset {mustBeA(options.ndiDataset, 'ndi.dataset')} = ndi.dataset.empty()
end

success = false;
message = '';

% a) Check if session is ingested
if ~S.is_fully_ingested()
    message = 'Session is not fully ingested.';
    return;
end

% b) Check duplicates locally and online

% Local check (if ndiDataset is provided)
if ~isempty(options.ndiDataset)
    % Check if session is already in the local dataset
    [~, id_list] = options.ndiDataset.session_list();
    if any(strcmp(S.id(), id_list))
        message = ['Session ' S.id() ' is already in the local dataset.'];
        return;
    end

    % Check if cloudDatasetId matches
    [local_cloud_id, ~] = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(options.ndiDataset);
    if ~isempty(local_cloud_id) && ~strcmp(local_cloud_id, cloudDatasetId)
        message = ['The provided ndiDataset is linked to a different cloud dataset (' local_cloud_id ') than the one provided (' cloudDatasetId ').'];
        return;
    end
end

% Remote check
% Retrieve the dataset_session_info document from the cloud
% Since we don't know the ID, we have to list/search.
[b, answer, apiResponse] = ndi.cloud.api.documents.listDatasetDocumentsAll(cloudDatasetId);
if ~b
    message = ['Failed to list remote documents: ' apiResponse.StatusLine.ReasonPhrase];
    if isfield(answer, 'message')
        message = [message ' - ' answer.message];
    end
    return;
end

% Find the dataset_session_info document
dataset_session_info_doc_summary = [];
if ~isempty(answer)
    for i = 1:numel(answer)
        if strcmp(answer(i).className, 'dataset_session_info')
            dataset_session_info_doc_summary = answer(i);
            break;
        end
    end
end

current_session_info = struct([]);
doc_content = [];

if ~isempty(dataset_session_info_doc_summary)
    % Get the full document content
    [b, doc_content, apiResponse] = ndi.cloud.api.documents.getDocument(dataset_session_info_doc_summary.id);
    if ~b
        message = ['Failed to retrieve dataset_session_info document: ' apiResponse.StatusLine.ReasonPhrase];
        return;
    end

    if isfield(doc_content.document_properties, 'dataset_session_info') && ...
       isfield(doc_content.document_properties.dataset_session_info, 'dataset_session_info')
        current_session_info = doc_content.document_properties.dataset_session_info.dataset_session_info;
    end
end

% Check if session ID exists in remote info
if ~isempty(current_session_info)
    if isstruct(current_session_info)
        existing_ids = {current_session_info.session_id};
    elseif iscell(current_session_info)
        existing_ids = cellfun(@(x) x.session_id, current_session_info, 'UniformOutput', false);
    else
        existing_ids = {};
    end

    if any(strcmp(S.id(), existing_ids))
        message = ['Session ' S.id() ' is already in the remote dataset.'];
        return;
    end
end

% c) Adjust dataset_session_information document and upload
% d) If a local dataset is provided, sync it

if ~isempty(options.ndiDataset)
    % Branch for local dataset provided: Add locally and Sync
    try
        options.ndiDataset.add_ingested_session(S);
    catch ME
        message = ['Failed to add session to local dataset: ' ME.message];
        return;
    end

    % Use uploadDataset to push changes.
    syncOpts = ndi.cloud.sync.SyncOptions();

    [success, ~, msg] = ndi.cloud.uploadDataset(options.ndiDataset, syncOpts);
    if ~success
        message = ['Sync failed: ' msg];
        return;
    end

else
    % Branch for NO local dataset (Manual remote update)
    if isempty(dataset_session_info_doc_summary)
         message = 'Remote dataset does not have a dataset_session_info document, and no local dataset context was provided to create one.';
         return;
    end

    % Create new session info struct
    new_session_info = ndi.dataset.session_info_struct(S, 0);

    % Also clear input2 (path) as in add_ingested_session for ndi.session.dir
    if isa(S, 'ndi.session.dir')
        new_session_info.session_creator_input2 = '';
    end

    % Append to list
    updated_session_info = current_session_info;
    if iscell(updated_session_info)
        updated_session_info{end+1} = new_session_info;
    else
         try
            updated_session_info(end+1) = new_session_info;
         catch
             updated_session_info = vlt.data.structvcat(updated_session_info, new_session_info);
         end
    end

    % Update the dataset_session_info document
    doc_content.document_properties.dataset_session_info.dataset_session_info = updated_session_info;
    json_doc = vlt.data.prettyjson(doc_content.document_properties);

    [b, ~, apiResponse] = ndi.cloud.api.documents.updateDocument(cloudDatasetId, dataset_session_info_doc_summary.id, json_doc);
    if ~b
         message = ['Failed to update dataset_session_info document: ' apiResponse.StatusLine.ReasonPhrase];
         return;
    end

    % Upload session documents (content)
    % Since we don't have a local dataset to manage the sync, we manually upload the session's documents.
    docs_to_upload = S.database_search(ndi.query('','isa','base'));

    if ~isempty(docs_to_upload)
        ndi.cloud.upload.uploadDocumentCollection(cloudDatasetId, docs_to_upload, "onlyUploadMissing", true);
    end

    success = true;
end

end
