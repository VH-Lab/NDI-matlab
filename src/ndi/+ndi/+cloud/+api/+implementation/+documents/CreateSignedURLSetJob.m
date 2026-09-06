classdef CreateSignedURLSetJob < ndi.cloud.api.call
%CREATESIGNEDURLSETJOB Implementation for POST .../signed-url-set-jobs.
%
%   Kicks off a server-side worker that signs every file a document references
%   and writes the whole uid -> URL map as one gzipped JSON blob. Returns 202
%   with a jobId; poll ndi.cloud.api.documents.getSignedURLSetJobStatus (or
%   waitForSignedURLSetJob) until the job is ready, then fetch the result with
%   ndi.cloud.api.documents.getSignedURLSetResult.
%
%   This is the path for documents referencing thousands of files, where
%   pagination is the wrong shape for the access pattern.

    properties
        fileSeries (1,1) string = ""
    end

    methods
        function this = CreateSignedURLSetJob(args)
            %CREATESIGNEDURLSETJOB Creates a new CreateSignedURLSetJob call.
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentID (1,1) string
                args.fileSeries (1,1) string = ""
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.fileSeries = args.fileSeries;
            this.endpointName = 'create_signed_url_set_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.
            %
            %   Outputs:
            %       b      - True if the job was accepted (HTTP 202).
            %       answer - On success, a struct with jobId, datasetId,
            %                documentId, statusUrl and pollAfterSec. On failure,
            %                the error body returned by the server.

            % b stays false unless the status check below sets it; answer is
            % assigned on every path, so it is not pre-initialized.
            b = false;

            token = ndi.cloud.authenticate();

            baseURL = ndi.cloud.api.url('create_signed_url_set_job', ...
                'dataset_id', this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

            if strlength(this.fileSeries) > 0
                apiURL = matlab.net.URI(string(baseURL) + "?fileSeries=" + ...
                    urlencode(char(this.fileSeries)));
            else
                apiURL = baseURL;
            end

            method = matlab.net.http.RequestMethod.POST;
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(...
                matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, ...
                matlab.net.http.MessageBody(struct()));

            apiResponse = send(request, apiURL);

            % The endpoint answers 202 Accepted, not 200.
            if (apiResponse.StatusCode == 202 || apiResponse.StatusCode == 200)
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
