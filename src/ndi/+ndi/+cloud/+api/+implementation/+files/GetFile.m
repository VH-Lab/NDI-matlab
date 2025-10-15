classdef GetFile < ndi.cloud.api.call
%GETFILE A utility class for downloading a file from a pre-signed URL.
%   This class handles the low-level HTTP GET request required to download
%   a file's contents from a URL. It supports using both MATLAB's native
%   `websave` function and the system's `curl` command-line tool.

    properties
        downloadURL (1,1) string
        downloadedFile (1,1) string
        useCurl (1,1) logical
    end

    methods
        function this = GetFile(args)
            %GETFILE Construct a new GetFile object.
            arguments
                args.downloadURL (1,1) string
                args.downloadedFile (1,1) string
                args.useCurl (1,1) logical = false
            end
            this.downloadURL = args.downloadURL;
            this.downloadedFile = args.downloadedFile;
            this.useCurl = args.useCurl;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the file download using the selected method.

            if this.useCurl
                % --- Method 1: Use curl system command ---
                [b, answer, apiResponse, apiURL] = this.executeWithCurl();
            else
                % --- Method 2: Use native MATLAB websave ---
                [b, answer, apiResponse, apiURL] = this.executeWithWebsave();
            end
        end

        function [b, answer, apiResponse, apiURL] = executeWithWebsave(this)
            % Implementation using MATLAB's native websave
            b = false;
            answer = [];
            apiResponse = [];
            apiURL = this.downloadURL;

            try
                options = weboptions('ContentType', 'binary', 'Timeout', 60);
                websave(this.downloadedFile, this.downloadURL, options);
                b = true;
                answer = ['File downloaded successfully to ' this.downloadedFile];
            catch ME
                apiResponse = ME;
                answer = ['Error downloading file: ' ME.message];
            end
        end

        function [b, answer, apiResponse, apiURL] = executeWithCurl(this)
            % Implementation using a system call to curl
            b = false;
            apiURL = this.downloadURL; % Return the URL as a string

            command = sprintf('curl -L -o "%s" "%s"', this.downloadedFile, this.downloadURL);

            [status, result] = system(command);

            b = (status == 0);
            answer = result;

            % Create a simple struct for the response
            apiResponse = struct('StatusCode', 'N/A (cURL)', 'StatusLine', "Exit Status: " + status);
        end
    end
end