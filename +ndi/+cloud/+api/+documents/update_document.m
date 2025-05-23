function response = update_document(file_path, dataset_id, document_id, document)
    % UPDATE_DOCUMENT - update a document
    %
    % RESPONSE = ndi.cloud.api.documents.UPDATE_DOCUMENT(FILE_PATH, DATASET_ID, DOCUMENT_ID, DOCUMENT)
    %
    % Inputs:
    %   FILE_PATH - a string representing the file path
    %   DATASET_ID - a string representing the dataset id
    %   DOCUMENT_ID -  a string representing the document id
    %   DOCUMENT - a JSON object representing the updated version of the
    %   document
    %
    % Outputs:
    %   RESPONSE - the updated document summary
    %
    fid = fopen(file_path,'w');
    fprintf(fid,'%s',document);
    fclose(fid);

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.POST;

    provider = matlab.net.http.io.FileProvider(file_path);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, provider);

    url = ndi.cloud.api.url('update_document', 'dataset_id', dataset_id, 'document_id', document_id);

    response = req.send(url);
    if isfile(file_path)
        delete(file_path);
    end

    if (response.StatusCode == 200)
        % Request succeeded
        % document_id = response.Body.Data.id;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
