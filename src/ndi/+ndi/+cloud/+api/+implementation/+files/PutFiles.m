classdef PutFiles
%PUTFILES A utility class for uploading a file to a pre-signed URL.
%   This class handles the low-level HTTP PUT request required to upload
%   a file's contents to a URL. It supports using both MATLAB's native
%   HTTP client and the system's `curl` command-line tool.
%
%   When the upload is a bulk (zip) upload, the caller can pass the
%   jobId returned by ndi.cloud.api.files.getFileCollectionUploadURL and
%   set waitForCompletion=true so PutFiles waits for server-side
%   extraction to finish before returning.

    properties
        preSignedURL (1,1) string
        filePath (1,1) string
        useCurl (1,1) logical
        jobId (1,1) string
        waitForCompletion (1,1) logical
        timeout (1,1) double
    end

    methods
        function this = PutFiles(args)
            %PUTFILES Construct a new PutFiles object.
            arguments
                args.preSignedURL (1,1) string
                args.filePath (1,1) string {mustBeFile}
                args.useCurl (1,1) logical = true
                args.jobId (1,1) string = ""
                args.waitForCompletion (1,1) logical = false
                args.timeout (1,1) double {mustBePositive} = 60
            end
            this.preSignedURL = args.preSignedURL;
            this.filePath = args.filePath;
            this.useCurl = args.useCurl;
            this.jobId = args.jobId;
            this.waitForCompletion = args.waitForCompletion;
            this.timeout = args.timeout;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the file upload using the selected method.
            %   When waitForCompletion is true and jobId is non-empty, the
            %   call additionally waits for the server-side bulk extraction
            %   job to reach a terminal state before returning. b will only
            %   be true if both the PUT and the extraction succeed.

            if this.waitForCompletion && strlength(this.jobId) == 0
                error('NDI:CloudApi:PutFiles:MissingJobId', ...
                    ['waitForCompletion=true requires a non-empty jobId. ' ...
                     'Single-file uploads have no server-side job to wait on; ' ...
                     'omit waitForCompletion, or obtain a jobId from ' ...
                     'ndi.cloud.api.files.getFileCollectionUploadURL.']);
            end

            if this.useCurl
                [b, answer, apiResponse, apiURL] = this.executeWithCurl();
            else
                [b, answer, apiResponse, apiURL] = this.executeWithMATLAB();
            end

            % Only wait if the PUT succeeded and the caller asked for it.
            if b && this.waitForCompletion
                [wb, wans, wresp, wurl] = ndi.cloud.api.files.waitForBulkUpload(...
                    this.jobId, 'timeout', this.timeout);
                b = wb;
                answer = wans;
                apiResponse = wresp;
                apiURL = wurl;
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

            % -f so HTTP errors (403/404 on a stale signed URL, etc.) surface
            % as a non-zero exit. Pin Content-Type to application/octet-stream
            % and Accept-Encoding to identity so the object metadata stored in
            % S3 is predictable regardless of the client's environment.
            command = sprintf(['curl -fsSL -X PUT --upload-file "%s" ' ...
                '-H "Content-Type: application/octet-stream" ' ...
                '-H "Accept-Encoding: identity" ' ...
                '"%s"'], this.filePath, this.preSignedURL);

            [status, result] = system(command);

            b = (status == 0);
            answer = result;

            % Create a simple struct for the response to be used by APIMessage
            apiResponse = struct('StatusCode', 'N/A (cURL)', 'StatusLine', "Exit Status: " + status);
        end
    end
end
