function [response] = put_files(presigned_url, file_path)
    % PUT_FILES - upload the file at FILE_PATH to the presigned url
    %
    % [OUTPUT] = ndi.cloud.api.files.PUT_FILES(PRESIGNED_URL, FILE_PATH)
    %
    % Inputs:
    %   PRESIGNED_URL - a string representing the url obtained from ndi.cloud.api.files.get_file_upload_url or get_raw_file_upload_url
    %   FILE_PATH - a string representing the path to the file to be uploaded
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the response of the upload

    method = matlab.net.http.RequestMethod.PUT;
    provider = matlab.net.http.io.FileProvider(file_path);
    req = matlab.net.http.RequestMessage(method, [], provider);
    [response, ~, ~] = req.send(presigned_url);
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
    % cmd = sprintf("curl '%s' --upload-file '%s'", presigned_url, file_path);

    % Run the curl command and capture the output
    % [status, output] = system(cmd);
end
