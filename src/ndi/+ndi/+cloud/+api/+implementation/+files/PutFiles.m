classdef PutFiles
%PUTFILES Implementation class for uploading a file to a pre-signed URL.
%   This is a utility class and does not inherit from ndi.cloud.api.call
%   because the URL is provided directly, not constructed via the endpoint map.

    properties
        preSignedURL
        filePath
    end

    methods
        function this = PutFiles(args)
            %PUTFILES Creates a new PutFiles object.
            %
            %   Inputs:
            %       'preSignedURL' - The pre-signed URL to upload the file to.
            %       'filePath'     - The local path to the file to upload.
            %
            arguments
                args.preSignedURL (1,1) string
                args.filePath (1,1) string {mustBeFile}
            end
            
            this.preSignedURL = args.preSignedURL;
            this.filePath = args.filePath;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the PUT request to upload the file.
            
            % Initialize outputs
            b = false;
            answer = [];
            apiURL = this.preSignedURL; % The URL is the one provided

            try
                method = matlab.net.http.RequestMethod.PUT;
                provider = matlab.net.http.io.FileProvider(this.filePath);

                % The server expects minimal headers for a pre-signed PUT
                headers = [matlab.net.http.HeaderField('Content-Type', ''), ...
                           matlab.net.http.HeaderField('Expect',''), ...
                           matlab.net.http.HeaderField('Content-Disposition', ''), ...
                           matlab.net.http.HeaderField('Accept-Encoding', ''), ...
                           matlab.net.http.HeaderField('Accept','*/*')];
                
                request = matlab.net.http.RequestMessage(method, headers, provider);
                
                apiResponse = request.send(this.preSignedURL);
                
                if (apiResponse.StatusCode == 200)
                    b = true;
                    answer = 'File uploaded successfully.';
                else
                    if isprop(apiResponse.Body, 'Data')
                        answer = apiResponse.Body.Data;
                    else
                        answer = apiResponse.Body;
                    end
                end
            catch ME
                b = false;
                answer = ME.message;
                apiResponse = [];
            end
        end
    end
end


