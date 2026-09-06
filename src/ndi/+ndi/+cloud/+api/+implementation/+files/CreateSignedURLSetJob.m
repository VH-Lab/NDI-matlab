classdef CreateSignedURLSetJob < ndi.cloud.api.call
%CREATESIGNEDURLSETJOB Implementation for the async signed-URL-set job POST.
%
%   POST /datasets/{datasetId}/documents/{documentId}/signed-url-set-jobs
%
%   Kicks off a server-side worker that signs every file the document
%   references and writes the UID -> signed URL map as a gzipped JSON
%   blob to S3. Returns a jobId; poll with GetSignedURLSetJob until the
%   job is ready. See ndi.cloud.api.files.createSignedURLSetJob for the
%   user-facing wrapper.

    methods
        function this = CreateSignedURLSetJob(args)
            arguments
                args.cloudDatasetID  (1,1) string
                args.cloudDocumentID (1,1) string
            end
            this.cloudDatasetID  = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.endpointName = 'create_signed_url_set_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('create_signed_url_set_job', ...
                'dataset_id',  this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

            method = matlab.net.http.RequestMethod.POST;

            % The endpoint takes no body; send an empty JSON object so the
            % gateway doesn't reject a 0-byte POST.
            body = matlab.net.http.MessageBody(struct());

            acceptField        = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField   = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            apiResponse = send(request, apiURL);

            % The API returns 202 Accepted with the job info on success.
            if (apiResponse.StatusCode == 202)
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
