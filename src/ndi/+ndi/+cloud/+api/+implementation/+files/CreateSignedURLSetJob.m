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

    properties
        fileSeries (1,1) string
        % Which namespace cloudDocumentID is in: "cloud" (mongo _id) or
        % "ndi" (data.base.id), resolved server-side on the ndi-documents
        % route. Stated, never sniffed -- see NDI-matlab#968.
        idNamespace (1,1) string
    end

    methods
        function this = CreateSignedURLSetJob(args)
            arguments
                args.cloudDatasetID  (1,1) string
                args.cloudDocumentID (1,1) string
                args.idNamespace     (1,1) string ...
                    {mustBeMember(args.idNamespace,["cloud","ndi"])} = "cloud"
                args.fileSeries      (1,1) string = ""
            end
            this.cloudDatasetID  = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.idNamespace = args.idNamespace;
            this.fileSeries = args.fileSeries;
            if strcmp(this.idNamespace, "ndi")
                this.endpointName = 'create_ndi_signed_url_set_job';
            else
                this.endpointName = 'create_signed_url_set_job';
            end
        end

        function apiURL = buildURL(this)
            %BUILDURL The full request URI, query included.
            %
            %   Separate from execute for the same reason as in
            %   GetSignedURLSet: which route the namespace selects is then
            %   checkable without a server, and a wrong route here is a 404
            %   that looks exactly like a missing document.

            if strcmp(this.idNamespace, "ndi")
                apiURL = ndi.cloud.api.url('create_ndi_signed_url_set_job', ...
                    'dataset_id',      this.cloudDatasetID, ...
                    'ndi_document_id', this.cloudDocumentID);
            else
                apiURL = ndi.cloud.api.url('create_signed_url_set_job', ...
                    'dataset_id',  this.cloudDatasetID, ...
                    'document_id', this.cloudDocumentID);
            end

            % Restrict the job to one file series' members.
            if strlength(this.fileSeries) > 0
                q = matlab.net.QueryParameter('fileSeries', char(this.fileSeries));
                if isempty(apiURL.Query)
                    apiURL.Query = q;
                else
                    apiURL.Query = [apiURL.Query q];
                end
            end
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % b stays false unless the 202 check below sets it; answer is
            % assigned on every path out of that check, so it is not
            % pre-initialized. Same shape as GetSignedURLSet.execute.
            b = false;

            token = ndi.cloud.authenticate();

            apiURL = this.buildURL();

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
