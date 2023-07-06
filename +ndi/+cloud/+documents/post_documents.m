function [status, response] = post_documents(file_path, dataset_id, document, auth_token)
% POST_DOCUMENTS - add a document to the dataset
%
% [STATUS,RESPONSE] = ndi.cloud.documents.post_documents(DATASET_ID, DOCUMENT, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT - a string of JSON object representing the new document
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - the new document summary
%

% document = jsonencode(document);

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/documents', dataset_id);
% cmd = sprintf("curl -X 'POST' '%s' " + ...
%     "-H 'accept: application/json' " + ...
%     "-H 'Authorization: Bearer %s' " +...
%     "-H 'Content-Type: application/json' " +...
%     " -d '%s' ", url, auth_token, document);

% ndi_globals

%   '/private/var/folders/pf/3ttr_5sx0jg_6kksdyhd9w6m0000gn/T//nditemp'
%%add a random number ndi.ido

fid = fopen(file_path,'w');
fprintf(fid,'%s',document);
fclose(fid);

% directly from files
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " +...
    "-H 'Content-Type: application/json' " +...
    " -d @%s ", url, auth_token, file_path);
% 
% cmd = sprintf("curl -X 'POST' '%s' " + ...
%     "-H 'accept: application/json' " + ...
%     "-H 'Authorization: Bearer %s' " +...
%     "-H 'Content-Type: application/json' " +...
%     " --data-urlencode %s ", url, auth_token, simple_doc);


disp(cmd);

% Run the curl command and capture the output
[status, output] = system(cmd);
if exist(file_path, 'file')==2,
  delete(file_path);
end

% Check the status code and handle any errors
if status ~= 0
    error('Failed to run curl command: %s', output);
end

% Process the JSON response; if the command failed, it might be a plain text error message
try,
	response = jsondecode(output);
catch,
	error(['Command failed with message: ' output ]);
end;
if isfield(response, 'error')
    error(response.error);
end
end
