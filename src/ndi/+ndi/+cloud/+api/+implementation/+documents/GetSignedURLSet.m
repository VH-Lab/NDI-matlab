classdef GetSignedURLSet < ndi.cloud.api.call
%GETSIGNEDURLSET Implementation for GET .../documents/{documentId}/signed-url-set.
%
%   Returns one page of the uid -> signed download URL map for the files a
%   document references. The set is paginated over uid-sorted order with an
%   opaque cursor, so a fixed per-page bound holds regardless of set size.

    properties
        limit (1,1) double = 500
        cursor (1,1) string = ""
        fileSeries (1,1) string = ""
    end

    methods
        function this = GetSignedURLSet(args)
            %GETSIGNEDURLSET Creates a new GetSignedURLSet call.
            %
            %   Inputs:
            %       'cloudDatasetID'  - Id of the dataset.
            %       'cloudDocumentID' - Id of the document.
            %       'limit'           - Max URLs per page. Server default 500,
            %                           server cap 1000.
            %       'cursor'          - Opaque cursor from a previous page's
            %                           nextCursor. Omit for the first page.
            %       'fileSeries'      - Restrict the set to the members of one
            %                           named file series. Omit for every file
            %                           the document references.
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentID (1,1) string
                args.limit (1,1) double {mustBePositive, mustBeInteger} = 500
                args.cursor (1,1) string = ""
                args.fileSeries (1,1) string = ""
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.limit = args.limit;
            this.cursor = args.cursor;
            this.fileSeries = args.fileSeries;
            this.endpointName = 'get_signed_url_set';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call for one page.
            %
            %   Outputs:
            %       b      - True if the call succeeded.
            %       answer - On success, a struct with fields:
            %                  files      - containers.Map from uid to signed URL
            %                  nextCursor - cursor for the next page, "" if this
            %                               was the last page
            %                  expiresAt  - when the signed URLs expire
            %                On failure, the error body returned by the server.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            baseURL = ndi.cloud.api.url('get_signed_url_set', ...
                'dataset_id', this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

            apiURL = matlab.net.URI(string(baseURL) + this.queryString());

            method = matlab.net.http.RequestMethod.GET;
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            % Keep the raw payload: the response keys are DID uids, which
            % JSONDECODE renames when they start with a digit. See
            % ndi.cloud.api.implementation.documents.signedURLFileMap.
            httpOptions = matlab.net.http.HTTPOptions('SavePayload', true);

            apiResponse = send(request, apiURL, httpOptions);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = ndi.cloud.api.implementation.documents.signedURLSetPage(...
                    apiResponse);
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end

        function q = queryString(this)
            %QUERYSTRING Builds the query for this page.
            %   Optional parameters are appended here rather than templated in
            %   ndi.cloud.api.url, which requires every templated parameter to
            %   be non-empty.
            parts = string.empty(1,0);
            parts(end+1) = "limit=" + string(this.limit);
            if strlength(this.cursor) > 0
                parts(end+1) = "cursor=" + urlencode(char(this.cursor));
            end
            if strlength(this.fileSeries) > 0
                parts(end+1) = "fileSeries=" + urlencode(char(this.fileSeries));
            end
            q = "?" + join(parts, "&");
        end
    end
end
