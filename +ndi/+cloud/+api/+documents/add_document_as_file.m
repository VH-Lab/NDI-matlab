function [response, document_id] = add_document_as_file(dataset_id, document)
    % ADD_DOCUMENT - add a document to the dataset using a file for upload
    %
    % [RESPONSE, DOCUMENT_ID] = ndi.cloud.api.documents.ADD_DOCUMENT(DATASET_ID, DOCUMENT)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   DOCUMENT - a string of JSON object representing the new document
    %
    % Outputs:
    %   RESPONSE - the new document summary
    %
    % Note: use this function if documents are too large to send as json

    % Todo: merge with add_document

    [file_path, file_cleanup_obj] = saveDocumentToTemporaryFile(document);

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.POST;

    provider = matlab.net.http.io.FileProvider(file_path);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, provider);

    url = ndi.cloud.api.url('add_document', 'dataset_id', dataset_id);

    response = req.send(url);

    
    if (response.StatusCode == 200)
        % Request succeeded
        document_id = response.Body.Data.id;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end

    clear file_cleanup_obj
end

function [file_path, file_cleanup_obj] = saveDocumentToTemporaryFile(document)
    
    file_path = [tempname, '.json'];

    fid = fopen(file_path, 'w');
    fprintf(fid, '%s', document);
    fclose(fid);

    file_cleanup_obj = onCleanup(@() delete(file_path));
end
