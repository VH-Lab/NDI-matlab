classdef GetFileUploadURL < ndi.cloud.api.call
%GETFILEUPLOADURL Implementation for getting a single file upload URL.

    properties
        cloudFileUID
        checksumCRC32 (1,1) string = "" % base64 big-endian CRC-32, or "" for none
    end

    methods
        function this = GetFileUploadURL(args)
            %GETFILEUPLOADURL Creates a new GetFileUploadURL call.
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %       'cloudFileUID'   - The unique identifier for the file.
            %       'checksumCRC32'  - (Optional) The file's CRC-32, base64 of
            %                          its 4-byte big-endian value. Sent as the
            %                          checksumCRC32 query parameter.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudFileUID (1,1) string
                args.checksumCRC32 (1,1) string = ""
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudFileUID = args.cloudFileUID;
            this.checksumCRC32 = args.checksumCRC32;
            this.endpointName = 'get_file_upload_url';
        end

        function apiURL = buildURL(this, organizationId)
            %BUILDURL The upload URL request for ORGANIZATIONID, with the
            %   checksumCRC32 query parameter when a checksum was given.
            arguments
                this (1,1) ndi.cloud.api.implementation.files.GetFileUploadURL
                organizationId {mustBeText}
            end
            apiURL = ndi.cloud.api.url('get_file_upload_url', ...
                'dataset_id', this.cloudDatasetID, ...
                'organization_id', organizationId, ...
                'file_uid', this.cloudFileUID);
            if strlength(this.checksumCRC32) > 0
                % QueryParameter percent-encodes the base64 '+', '/' and '='.
                q = matlab.net.QueryParameter('checksumCRC32', char(this.checksumCRC32));
                if isempty(apiURL.Query)
                    apiURL.Query = q;
                else
                    apiURL.Query = [apiURL.Query q];
                end
            end
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            % This endpoint requires organizationId, which we get from the dataset info
            [get_b, dsetinfo, ~, ~] = ndi.cloud.api.datasets.getDataset(this.cloudDatasetID);
            if ~get_b
                apiResponse = [];
                apiURL = [];
                answer = 'Failed to retrieve dataset info to determine organization ID.';
                return;
            end
            
            apiURL = this.buildURL(dsetinfo.organizationId);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data.url;
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end
end

