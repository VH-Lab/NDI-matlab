function [status,response, dataset] = post_bulk_delete(dataset_id,document_ids, auth_token)
%POST_BULK_DELETE - Delete a set of documents from the dataset
%
% [STATUS,RESPONSE, DATASET] = ndi.cloud.datasets.post_bulk_delete(DATASET_ID, DOCUMENT_IDS, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - an id of the dataset
%   DOCUMENT_IDS - a cell array of document ids to delete
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did the post request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%   DATASET - the updated dataset

document_ids_str = jsonencode(document_ids);
document_ids_str = strrep(document_ids_str, '"', '''');

url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/documents/bulk-delete/', dataset_id);
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " +...
    "-H 'Content-Type: application/json' " + ...
    "-d '%s'", url, auth_token, document_ids_str);

% Run the curl command and capture the output
[status, output] = system(cmd);
dataset = '';
% Check the status code and handle any errors
if status
    error('Failed to run curl command: %s', output);
else
    % Process the JSON response
    dataset = jsondecode(output);
    if isfield(dataset, 'error')
        error(dataset.error);
    end
end

end
