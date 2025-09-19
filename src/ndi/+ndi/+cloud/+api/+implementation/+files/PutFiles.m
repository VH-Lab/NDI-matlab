classdef PutFiles
%PUTFILES A utility class for uploading a file to a pre-signed URL.
%   This class handles the low-level HTTP PUT request required to upload
%   a file's contents to a URL. It supports using both MATLAB's native
%   HTTP client and the system's `curl` command-line tool.

    properties
        preSignedURL (1,1) string
        filePath (1,1) string
        useCurl (1,1) logical
    end

    methods
        function this = PutFiles(args)
            %PUTFILES Construct a new PutFiles object.
            arguments
                args.preSignedURL (1,1) string
                args.filePath (1,1) string {mustBeFile}
                args.useCurl (1,1) logical = false
            end
            this.preSignedURL = args.preSignedURL;
            this.filePath = args.filePath;
            this.useCurl = args.useCurl;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the file upload using the selected method.
            
            if this.useCurl
                % --- Method 1: Use curl system command ---
                [b, answer, apiResponse, apiURL] = this.executeWithCurl();
            else
                % --- Method 2: Use native MATLAB HTTP client ---
                [b, answer, apiResponse, apiURL] = this.executeWithMATLAB();
            end
        end

        function [b, answer, apiResponse, apiURL] = executeWithMATLAB(this)
            % Implementation using MATLAB's native http library
            b = false;
            answer = [];
            apiResponse = [];
            apiURL = matlab.net.URI(this.preSignedURL);
            method = matlab.net.http.RequestMethod.PUT;
            provider = matlab.net.http.io.FileProvider(this.filePath);
            contentTypeField = matlab.net.http.HeaderField('Content-Type', 'application/octet-stream');
            request = matlab.net.http.RequestMessage(method, contentTypeField, provider);
            
            try
                apiResponse = send(request, apiURL);
                if (apiResponse.StatusCode == 200)
                    b = true;
                end
                answer = apiResponse.Body.Data;
            catch ME
                apiResponse = ME;
                answer = ME.message;
            end
        end

        function [b, answer, apiResponse, apiURL] = executeWithCurl(this)
            % Implementation using a system call to curl
            b = false;
            apiURL = this.preSignedURL; % Return the URL as a string
            
            command = sprintf('curl -X PUT --upload-file "%s" "%s"', this.filePath, this.preSignedURL);
            
            [status, result] = system(command);
            
            b = (status == 0);
            answer = result;
            
            % Create a simple struct for the response to be used by APIMessage
            apiResponse = struct('StatusCode', 'N/A (cURL)', 'StatusLine', "Exit Status: " + status);
        end
    end
end

