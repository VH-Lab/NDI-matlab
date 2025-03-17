function [status, file_detail, downloadUrl, response] = get_file_details(dataset_id, uid)
    % GET_FILE_DETAILS - Get the details, including the download url, for a individual file
    %
    % [STATUS,FILE_DETAIL, DOWNLOADURL, RESPONSE] = ndi.cloud.api.files.GET_FILE_DETAILS(DATASET_ID,UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   UID - a string representing the file uid
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   FILE_DETAIL - the details of the file
    %   DOWNLOADURL - the download url for the file
    %   RESPONSE - the response from the server
    
    [status, file_detail, downloadUrl, response] = ...
        ndi.cloud.api.datasets.get_file_details(dataset_id, uid);
end
