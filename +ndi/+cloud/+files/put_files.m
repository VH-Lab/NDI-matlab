function [status, output] = put_files(presigned_url, file_path, auth_token)
% GET_DOCUMENTS - get a document
%
% [STATUS, OUTPUT] = ndi.cloud.files.put_files(PRESIGNED_URL, FILE_PATH, AUTH_TOKEN)
%
% Inputs:
%   PRESIGNED_URL - a string representing the url obtained from ndi.cloud.api.files.get_files or get_files_raw
%   FILE_PATH - a string representing the path to the file to be uploaded
%   AUTH_TOKEN - a string representing the authentification token
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
