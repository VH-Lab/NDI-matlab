classdef GetSignedURLSet < ndi.cloud.api.call
%GETSIGNEDURLSET Implementation for GET .../documents/{documentId}/signed-url-set.
%
%   Returns one page of a UID -> signed URL map for the files that a
%   document references, cursor-paginated in UID-sorted order. See
%   ndi.cloud.api.files.getSignedURLSet for the user-facing wrapper.

    properties
        limit      (1,1) double
        cursor     (1,1) string
        fileSeries (1,1) string
    end

    methods
        function this = GetSignedURLSet(args)
            %GETSIGNEDURLSET Creates a new GetSignedURLSet call.
            arguments
                args.cloudDatasetID  (1,1) string
                args.cloudDocumentID (1,1) string
                args.limit           (1,1) double = 500
                args.cursor          (1,1) string = ""
                args.fileSeries      (1,1) string = ""
            end
            this.cloudDatasetID  = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.limit  = args.limit;
            this.cursor = args.cursor;
            this.fileSeries = args.fileSeries;
            this.endpointName = 'get_signed_url_set';
        end

        function apiURL = buildURL(this)
            %BUILDURL The full request URI, query included.
            %
            %   Separate from execute so the query assembly can be tested
            %   without a server: it is where limit, cursor and fileSeries
            %   turn into wire format, and a cursor is opaque server state
            %   that must survive being round-tripped.

            apiURL = ndi.cloud.api.url('get_signed_url_set', ...
                'dataset_id',  this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

            % limit is always sent; cursor and fileSeries only when set.
            q = matlab.net.QueryParameter('limit', sprintf('%d', this.limit));
            if strlength(this.cursor) > 0
                q = [q matlab.net.QueryParameter('cursor', char(this.cursor))];
            end
            % Restrict the set to one file series' members. A document holding
            % a dual pyramid references several; a viewer wants the level it
            % is showing, not all of them.
            if strlength(this.fileSeries) > 0
                q = [q matlab.net.QueryParameter('fileSeries', char(this.fileSeries))];
            end

            if isempty(apiURL.Query)
                apiURL.Query = q;
            else
                apiURL.Query = [apiURL.Query q];
            end
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = this.buildURL();
            method = matlab.net.http.RequestMethod.GET;
            acceptField        = matlab.net.http.HeaderField('accept', 'application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            % Keep the raw payload. The response keys are DID file uids, and
            % JSONDECODE renames any struct field that cannot be a MATLAB
            % identifier -- which a uid usually cannot, since did.ido mints
            % NUM2HEX(date) '_' NUM2HEX(rand) and that starts with a digit
            % more often than not. Reading uids off the decoded struct hands
            % callers uids that do not exist.
            httpOptions = matlab.net.http.HTTPOptions('SavePayload', true);
            apiResponse = this.sendRequest(request, apiURL, httpOptions);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = ndi.cloud.api.implementation.files.signedURLSetPage(...
                    apiResponse.Body.Data, apiResponse.Body.Payload);
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end

    methods (Access = protected)
        function response = sendRequest(~, request, url, httpOptions)
            %SENDREQUEST Perform the HTTP request. Seam: a test subclass
            %   overrides this to return a canned response.
            response = send(request, url, httpOptions);
        end
    end
end
