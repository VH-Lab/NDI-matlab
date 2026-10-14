classdef LookupFiles < ndi.cloud.api.call
%LOOKUPFILES Implementation class for looking up file records by uid.
%
%   One call to POST /datasets/{datasetId}/files/lookup, for at most
%   MaxUids uids. ndi.cloud.api.files.lookupFiles splits longer lists into
%   several calls.
%
%   See also: ndi.cloud.api.files.lookupFiles

    properties (Constant)
        MaxUids = 5000 % server limit per call
    end

    properties
        cloudFileUIDs (1,:) string
    end

    methods
        function this = LookupFiles(args)
            %LOOKUPFILES Creates a new LookupFiles API call object.
            %
            %   THIS = ndi.cloud.api.implementation.files.LookupFiles( ...
            %      'cloudDatasetID', ID, 'cloudFileUIDs', UIDS)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %       'cloudFileUIDs'  - String array of file uids, 1 to MaxUids
            %                          entries.
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudFileUIDs (1,:) string
            end
            if isempty(args.cloudFileUIDs)
                error('NDI:CloudApi:LookupFiles:NoUids', ...
                    'At least one file uid is required.');
            end
            if numel(args.cloudFileUIDs) > ndi.cloud.api.implementation.files.LookupFiles.MaxUids
                error('NDI:CloudApi:LookupFiles:TooManyUids', ...
                    'At most %d uids per call (got %d); use ndi.cloud.api.files.lookupFiles, which splits the list.', ...
                    ndi.cloud.api.implementation.files.LookupFiles.MaxUids, numel(args.cloudFileUIDs));
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudFileUIDs = args.cloudFileUIDs;
            this.endpointName = 'lookup_dataset_files';
        end

        function body = requestBody(this)
            %REQUESTBODY The JSON body sent to the server, as a struct.
            %
            %   When MATLAB encodes a scalar string to JSON it produces a bare
            %   string, not an array, so a single uid is sent twice (the server
            %   collapses duplicates), as BulkFetch does.
            uids = this.cloudFileUIDs;
            if isscalar(uids)
                uids = [uids uids];
            end
            body = struct('uids', uids);
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - On success, a struct with fields `files`
            %                      (Nx1 struct array: uid, uploaded, size,
            %                      crc32) and `missing` (string array). On
            %                      failure, the error body from the server.
            %       apiResponse  - The matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.

            b = false;

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url(this.endpointName, 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(this.requestBody());

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = ndi.cloud.api.implementation.files.lookupFilesResult(apiResponse.Body.Data);
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
