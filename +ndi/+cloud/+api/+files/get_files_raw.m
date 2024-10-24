function [status, response, upload_url] = get_files_raw(dataset_id, uid)
    % GET_FILES_RAW - get an upload URL for a raw data file that will be
    % published to AWS Open Data after review.
    % Same functionality as ndi.cloud.api.datasets.GET_FILES_RAW
    %
    % [STATUS,RESPONSE,UPLOAD_URL] = ndi.cloud.api.files.GET_FILES_RAW(DATASET_ID, UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   UID -  a string representing the unique identifier that can be used to
    %   reference the file in document
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the upload summary
    %   UPLOAD_URL - the upload URL to put the file to
    %

    [status, response, upload_url] = ndi.cloud.api.files.get_files_raw(dataset_id, uid);
end
