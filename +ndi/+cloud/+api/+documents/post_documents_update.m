function [status, response] = post_documents_update(file_path, dataset_id, document_id, document)
    % POST_DOCUMENTS_UPDATE - update a document
    %
    % [STATUS,RESPONSE] = ndi.cloud.api.documents.POST_DOCUMENTS_UPDATE(FILE_PATH, DATASET_ID, DOCUMENT_ID, DOCUMENT)
    %
    % Inputs:
    %   FILE_PATH - a string representing the file path
    %   DATASET_ID - a string representing the dataset id
    %   DOCUMENT_ID -  a string representing the document id
    %   DOCUMENT - a JSON object representing the updated version of the
    %   document
    %
    % Outputs:
    %   STATUS - did post request work? 1 for no, 0 for yes
    %   RESPONSE - the updated document summary
    %
    fid = fopen(file_path,'w');
    fprintf(fid,'%s',document);
    fclose(fid);

    [auth_token, ~] = ndi.cloud.uilogin();

    method = matlab.net.http.RequestMethod.POST;

    provider = matlab.net.http.io.FileProvider(file_path);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, provider);

    url = matlab.net.URI(ndi.cloud.api.url('post_documents_update', 'dataset_id', dataset_id, 'document_id', document_id));

    response = req.send(url);
    if exist(file_path, 'file')==2,
        delete(file_path);
    end
    status = 1;

    if (response.StatusCode == 200)
        status = 0;
        document_id = response.Body.Data.id;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
