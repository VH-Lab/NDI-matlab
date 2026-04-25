classdef GetFileCollectionUploadURL < ndi.cloud.api.call
%GETFILECOLLECTIONUPLOADURL Implementation for getting a bulk file upload URL.

    methods
        function this = GetFileCollectionUploadURL(args)
            %GETFILECOLLECTIONUPLOADURL Creates a new GetFileCollectionUploadURL call.
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %
            arguments
                args.cloudDatasetID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.endpointName = 'get_file_collection_upload_url';
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
            
            apiURL = ndi.cloud.api.url('get_file_collection_upload_url', ...
                'dataset_id', this.cloudDatasetID, ...
                'organization_id', dsetinfo.organizationId);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201)
                b = true;
                data = apiResponse.Body.Data;
                jobId = "";
                if isstruct(data) && isfield(data, 'jobId') && ~isempty(data.jobId)
                    jobId = string(data.jobId);
                else
                    % Diagnostic: callers (e.g. putFiles with
                    % waitForCompletion=true) require a jobId, and a silent
                    % empty value here surfaces as a confusing
                    % MissingJobId error several layers later. Dump what
                    % the server actually returned so the failure mode is
                    % obvious.
                    fns = "<not a struct>";
                    if isstruct(data)
                        try
                            fns = strjoin(string(fieldnames(data)), ',');
                        catch
                            fns = "<unreadable>";
                        end
                    end
                    fprintf(['[getFileCollectionUploadURL] WARNING: server returned ', ...
                        'status %d but no usable ''jobId''. Body class=%s fields=%s. ', ...
                        'Body preview:\n'], ...
                        apiResponse.StatusCode, class(data), fns);
                    try
                        preview = jsonencode(data);
                        if strlength(preview) > 500
                            preview = char(extractBetween(preview, 1, 500)) + "...";
                        end
                        fprintf('[getFileCollectionUploadURL]   %s\n', string(preview));
                    catch
                        fprintf('[getFileCollectionUploadURL]   <unable to encode body>\n');
                    end
                end
                url = "";
                if isstruct(data) && isfield(data, 'url')
                    url = string(data.url);
                end
                answer = struct('url', url, 'jobId', jobId);
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

