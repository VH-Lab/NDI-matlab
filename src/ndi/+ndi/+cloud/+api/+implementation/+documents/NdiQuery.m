classdef NdiQuery < ndi.cloud.api.call
%NDIQUERY Implementation class for executing an NDI query.

    properties
        scope
        searchstructure
    end

    methods
        function this = NdiQuery(args)
            %NDIQUERY Creates a new NdiQuery API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.NdiQuery('scope', SCOPE, 'searchstructure', SEARCHSTRUCT, 'page', P, 'pageSize', PS)
            %
            %   Inputs:
            %       'scope'           - The scope of the search ('public', 'private', 'all').
            %       'searchstructure' - The search structure defining the query criteria (e.g. from an ndi.query or did.query object).
            %       'page'            - (Optional) The page number of results. Default is 1.
            %       'pageSize'        - (Optional) The number of results per page. Default is 20.
            %
            arguments
                args.scope (1,1) string {mustBeMember(args.scope, ["public", "private", "all"])}
                args.searchstructure (1,:) struct
                args.page (1,1) double = 1
                args.pageSize (1,1) double = 20
            end

            this.scope = args.scope;
            this.searchstructure = args.searchstructure;
            this.page = args.page;
            this.pageSize = args.pageSize;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to execute the NDI query.

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('ndiquery', ...
                'page', this.page, ...
                'page_size', this.pageSize);

            method = matlab.net.http.RequestMethod.POST;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            contentTypeField = matlab.net.http.HeaderField('Content-Type', 'application/json');
            headers = [acceptField authorizationField contentTypeField];

            % Construct the body
            bodyData = struct('scope', this.scope, 'searchstructure', this.searchstructure);

            % Ensure searchstructure is treated as an array even if it's a single struct
            if isstruct(bodyData.searchstructure)
                if isscalar(bodyData.searchstructure)
                     bodyData.searchstructure = {bodyData.searchstructure};
                else
                     % If it's a struct array, convert to cell array to ensure JSON array
                     c = num2cell(bodyData.searchstructure);
                     bodyData.searchstructure = c;
                end
            end

            request = matlab.net.http.RequestMessage(method, headers, bodyData);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                raw_answer = apiResponse.Body.Data;
                answer = raw_answer;

                % Standardize the output format
                doc_list = struct('id', {}, 'ndiId', {}, 'name', {}, 'className', {}, 'datasetId', {});

                if isfield(raw_answer, 'documents') && ~isempty(raw_answer.documents)
                    docs_from_api = raw_answer.documents;

                    % If docs_from_api is a cell array (which can happen with jsondecode of mixed types or list)
                    if iscell(docs_from_api)
                         % convert to struct array if possible, or iterate
                         for i = 1:numel(docs_from_api)
                             doc_in = docs_from_api{i};
                             doc_list(end+1) = ndi.cloud.api.implementation.documents.NdiQuery.process_doc_summary(doc_in);
                         end
                    else
                        for i = 1:numel(docs_from_api)
                            doc_in = docs_from_api(i);
                            doc_list(end+1) = ndi.cloud.api.implementation.documents.NdiQuery.process_doc_summary(doc_in);
                        end
                    end
                end

                answer.documents = doc_list;
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end

    methods (Static, Access = private)
        function doc_out = process_doc_summary(doc_in)
             doc_out.id = doc_in.id; % id is guaranteed to be there

            if isfield(doc_in, 'ndiId') && ~isempty(doc_in.ndiId)
                doc_out.ndiId = doc_in.ndiId;
            else
                doc_out.ndiId = '';
            end

            if isfield(doc_in, 'name') && ~isempty(doc_in.name)
                doc_out.name = doc_in.name;
            else
                doc_out.name = '';
            end

            if isfield(doc_in, 'className') && ~isempty(doc_in.className)
                doc_out.className = doc_in.className;
            else
                doc_out.className = '';
            end

            if isfield(doc_in, 'datasetId') && ~isempty(doc_in.datasetId)
                doc_out.datasetId = doc_in.datasetId;
            else
                doc_out.datasetId = '';
            end
        end
    end
end
