classdef ListActiveBulkUploads < ndi.cloud.api.call
%LISTACTIVEBULKUPLOADS Implementation for GET /datasets/{id}/bulk-uploads.
%
%   Returns the bulk upload jobs for a dataset. The server accepts a
%   `state` query parameter to filter by lifecycle state
%   ('active' (default), 'all', 'queued', 'extracting', 'complete',
%   'failed') and an optional `since` query parameter (ISO 8601) that
%   limits terminal jobs to those completed at or after it.

    properties
        state (1,1) string
        since datetime = datetime.empty
    end

    methods
        function this = ListActiveBulkUploads(args)
            %LISTACTIVEBULKUPLOADS Creates a new ListActiveBulkUploads call.
            arguments
                args.cloudDatasetID (1,1) string
                args.state (1,1) string = "active"
                args.since datetime {mustBeScalarOrEmpty} = datetime.empty
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.state = args.state;
            this.since = args.since;
            this.endpointName = 'list_dataset_bulk_uploads';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('list_dataset_bulk_uploads', ...
                'dataset_id', this.cloudDatasetID, ...
                'state', this.state);

            if ~isempty(this.since) && ~isnat(this.since)
                % Setting TimeZone converts a zoned datetime to UTC and
                % labels an unzoned one as UTC without changing its clock.
                sinceUtc = this.since;
                sinceUtc.TimeZone = 'UTC';
                sinceUtc.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
                q = matlab.net.QueryParameter('since', char(sinceUtc));
                apiURL.Query = [apiURL.Query q];
            end

            method = matlab.net.http.RequestMethod.GET;
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;
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
