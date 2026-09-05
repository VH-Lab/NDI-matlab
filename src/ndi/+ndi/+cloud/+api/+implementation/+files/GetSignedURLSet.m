classdef GetSignedURLSet < ndi.cloud.api.call
%GETSIGNEDURLSET Implementation for GET .../documents/{documentId}/signed-url-set.
%
%   Returns one page of a UID -> signed URL map for the files that a
%   document references, cursor-paginated in UID-sorted order. See
%   ndi.cloud.api.files.getSignedURLSet for the user-facing wrapper.

    properties
        limit  (1,1) double
        cursor (1,1) string
    end

    methods
        function this = GetSignedURLSet(args)
            %GETSIGNEDURLSET Creates a new GetSignedURLSet call.
            arguments
                args.cloudDatasetID  (1,1) string
                args.cloudDocumentID (1,1) string
                args.limit           (1,1) double = 500
                args.cursor          (1,1) string = ""
            end
            this.cloudDatasetID  = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.limit  = args.limit;
            this.cursor = args.cursor;
            this.endpointName = 'get_signed_url_set';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('get_signed_url_set', ...
                'dataset_id',  this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

            % Query params: limit is always sent; cursor only when set.
            q = matlab.net.QueryParameter('limit', sprintf('%d', this.limit));
            if strlength(this.cursor) > 0
                q = [q matlab.net.QueryParameter('cursor', char(this.cursor))];
            end
            if isempty(apiURL.Query)
                apiURL.Query = q;
            else
                apiURL.Query = [apiURL.Query q];
            end

            method = matlab.net.http.RequestMethod.GET;
            acceptField        = matlab.net.http.HeaderField('accept', 'application/json');
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
