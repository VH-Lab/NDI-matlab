function response = put_files(presigned_url, file_path)
    % PUT_FILES - upload the file at FILE_PATH to the presigned url
    %
    % RESPONSE = ndi.cloud.api.files.PUT_FILES(PRESIGNED_URL, FILE_PATH)
    %
    % Inputs:
    %   PRESIGNED_URL - a string representing the url obtained from ndi.cloud.api.files.get_file_upload_url or get_raw_file_upload_url
    %   FILE_PATH - a string representing the path to the file to be uploaded
    %
    % Outputs:
    %   RESPONSE - the response of the upload

    method = matlab.net.http.RequestMethod.PUT;
    provider = matlab.net.http.io.FileProvider(file_path);

    contentTypeHeader = [];
    %...
    %[matlab.net.http.HeaderField('Content-Type', ''), ...
    %    matlab.net.http.HeaderField('Expect',''), ...
    %    matlab.net.http.HeaderField('Content-Disposition', ''), ...
    %    matlab.net.http.HeaderField('Accept-Encoding', '') ...
    %    matlab.net.http.HeaderField('Accept','*/*')
    %    ];

    %options = matlab.net.http.HTTPOptions('UseProxy', false);

    req = matlab.net.http.RequestMessage(method, contentTypeHeader, provider);
    [response, ~, ~] = req.send(presigned_url);
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
