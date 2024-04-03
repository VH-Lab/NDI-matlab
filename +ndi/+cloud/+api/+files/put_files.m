function [status, output] = put_files(presigned_url, file_path)
% PUT_FILES - upload the file at FILE_PATH to the presigned url
%
% [STATUS, OUTPUT] = ndi.cloud.api.files.PUT_FILES(PRESIGNED_URL, FILE_PATH)
%
% Inputs:
%   PRESIGNED_URL - a string representing the url obtained from ndi.cloud.api.files.get_files or get_files_raw
%   FILE_PATH - a string representing the path to the file to be uploaded
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   OUTPUT - the output of the curl command

cmd = sprintf("curl '%s' --upload-file '%s'", presigned_url, file_path);

% Run the curl command and capture the output
[status, output] = system(cmd);

% Check the status code and handle any errors
if status ~= 0
    error('Failed to run curl command: %s', output);
end

end
