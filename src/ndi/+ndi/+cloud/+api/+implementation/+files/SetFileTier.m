classdef SetFileTier < ndi.cloud.api.call
%SETFILETIER Implementation for POST /datasets/{datasetId}/file-tier-jobs.
%
%   Kicks off an async job that moves the files referenced by a list of
%   documents to a target S3 storage class. Documents may be addressed by
%   cloud _id or NDI id; the server infers each selector's namespace unless
%   idNamespace is set explicitly. See
%   ndi-cloud-node/manuals/file-tier-design.md.

    properties
        documentIDs
        targetTier  (1,1) string
        idNamespace (1,1) string
    end

    methods
        function this = SetFileTier(args)
            arguments
                args.cloudDatasetID (1,1) string
                args.documentIDs
                args.targetTier     (1,1) string
                args.idNamespace    (1,1) string ...
                    {mustBeMember(args.idNamespace,["auto","cloud","ndi"])} = "auto"
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.documentIDs    = args.documentIDs;
            this.targetTier     = args.targetTier;
            this.idNamespace    = args.idNamespace;
            this.endpointName   = 'create_file_tier_job';
        end

        function apiURL = buildURL(this)
            apiURL = ndi.cloud.api.url(this.endpointName, ...
                'dataset_id', this.cloudDatasetID);
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;

            token = ndi.cloud.authenticate();
            apiURL = this.buildURL();

            % Normalize documentIDs to a cell array of char row vectors so
            % JSON encoding turns them into a plain array of strings.
            ids = this.documentIDs;
            if isstring(ids); ids = cellstr(ids); end
            if ischar(ids);   ids = {ids};         end
            if ~iscell(ids)
                error('ndi:cloud:api:setFileTier:BadInput', ...
                      'documentIDs must be a string array or cell array of ids');
            end
            selectors = cell(1, numel(ids));
            for i = 1:numel(ids)
                sel = struct('id', ids{i});
                if ~strcmp(this.idNamespace, "auto")
                    sel.kind = char(this.idNamespace);
                end
                selectors{i} = sel;
            end

            payload = struct( ...
                'targetTier',        char(this.targetTier), ...
                'documentSelectors', {selectors});

            method = matlab.net.http.RequestMethod.POST;
            body   = matlab.net.http.MessageBody(payload);

            acceptField        = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField   = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 202
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
