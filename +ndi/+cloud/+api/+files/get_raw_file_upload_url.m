function [response, upload_url] = get_raw_file_upload_url(dataset_id, uid)
    % GET_RAW_FILE_UPLOAD_URL - get an upload URL for a raw data file that will be
    % published to AWS Open Data after review.
    % Same functionality as ndi.cloud.api.datasets.GET_RAW_FILE_UPLOAD_URL
    %
    % [RESPONSE,UPLOAD_URL] = ndi.cloud.api.files.GET_RAW_FILE_UPLOAD_URL(DATASET_ID, UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   UID -  a string representing the unique identifier that can be used to
    %   reference the file in document
    %
    % Outputs:
    %   RESPONSE - the upload summary
    %   UPLOAD_URL - the upload URL to put the file to
    %

    [status, response, upload_url] = ndi.cloud.api.datasets.get_raw_file_upload_url(dataset_id, uid);
end
