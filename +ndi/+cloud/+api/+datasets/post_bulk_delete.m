function [status, response] = post_bulk_delete(dataset_id,document_ids)
    %POST_BULK_DELETE - Delete a set of documents from the dataset
    %
    % [STATUS, RESPONSE] = ndi.cloud.api.datasets.POST_BULK_DELETE(DATASET_ID, DOCUMENT_IDS)
    %
    % Inputs:
    %   DATASET_ID - an id of the dataset
    %   DOCUMENT_IDS - a cell array of document ids to delete
    %
    % Outputs:
    %   STATUS - did the post request work? 1 for no, 0 for yes
    %   response - the post request response

    auth_token = ndi.cloud.authenticate();
    json = struct();
    json.documentIds = document_ids;

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = matlab.net.URI(ndi.cloud.api.url('post_bulk_delete', 'dataset_id', dataset_id));

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end

    % url = ndi.cloud.api.url('post_bulk_delete', 'dataset_id', dataset_id);
    % s = struct();
    % s.documentIds = document_ids;
    % json_obj = jsonencode(s);
    % cmd = sprintf("curl -X 'POST' '%s' " + ...
    %     "-H 'accept: application/json' " + ...
    %     "-H 'Authorization: Bearer %s' " +...
    %     "-H 'Content-Type: application/json' " + ...
    %     "-d '%s'", url, auth_token, json_obj);
    %
    % % Run the curl command and capture the output
    % [status, output] = system(cmd);
    % response = output;
    % % Check the status code and handle any errors
    % if status
    %     error('Failed to run curl command: %s', output);
    % else
    %     % Process the JSON response; if the command failed, it might be a plain text error message
    %     try,
    %         response = jsondecode(output);
    %     catch,
    %         error(['Command failed with message: ' output ]);
    %     end;
    %     if isfield(response, 'error')
    %         error(response.error);
    %     end
    % end
end
