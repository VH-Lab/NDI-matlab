function [status, output] = put_files(presigned_url, file_path, auth_token)
% PUT_FILES - upload a file
%
% [STATUS,RESPONSE,DOCUMENT] = ndi.cloud.files.put_files(DATASET_ID, DOCUMENT_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT_ID -  a string representing the document id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%   DOCUMENT - A document object required by the user
%

% Construct the curl command with the organization ID and authentication token
% curl -X PUT -T /path/to/local/file.jpg -H "Content-Type: image/jpeg" "https://presigned-url"
% curl -X PUT -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: YOUR_CONTENT_TYPE" --upload-file /path/to/local/file.jpg "https://presigned-url"

% curl url --upload-file file_name

cmd = sprintf("curl '%s' --upload-file '%s'", presigned_url, file_path);

% Run the curl command and capture the output
[status, output] = system(cmd);

% Check the status code and handle any errors
if status ~= 0
    error('Failed to run curl command: %s', output);
end

end
