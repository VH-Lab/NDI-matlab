classdef NdiQueryAll < ndi.cloud.api.call
%NDIQUERYALL Implementation class for executing an NDI query repeatedly to get all matches.

    properties
        scope
        searchstructure
        retries (1,1) double = 10
    end

    methods
        function this = NdiQueryAll(args)
            %NDIQUERYALL Creates a new NdiQueryAll API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.NdiQueryAll('scope', SCOPE, 'searchstructure', SEARCHSTRUCT, 'pageSize', PS)
            %
            %   Inputs:
            %       'scope'           - The scope of the search ('public', 'private', 'all').
            %       'searchstructure' - The search structure defining the query criteria.
            %       'pageSize'        - (Optional) The number of results per page. Default is 1000.
            %       'retries'         - (Optional) The number of retries for each page. Default is 10.
            %
            arguments
                args.scope (1,1) string {mustBeMember(args.scope, ["public", "private", "all"])}
                args.searchstructure (1,:) struct
                args.pageSize (1,1) double = 1000
                args.retries (1,1) double = 10
            end

            this.scope = args.scope;
            this.searchstructure = args.searchstructure;
            this.pageSize = args.pageSize;
            this.retries = args.retries;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to execute the NDI query repeatedly.

            % Initialize outputs
            b = true;
            answer = struct('id', {}, 'ndiId', {}, 'name', {}, 'className', {}, 'datasetId', {});
            apiResponse = matlab.net.http.ResponseMessage.empty;
            apiURL = matlab.net.URI.empty;

            % 1. Fetch first page to get totalItems
            p = 1;
            [b_page, ans_page, resp_page, url_page] = this.fetch_page(p);

            apiURL(end+1) = url_page;
            apiResponse(end+1) = resp_page;

            if ~b_page
                b = false;
                answer = 'Failed to fetch first page of query results.';
                return;
            end

            % Process first page results
            if isstruct(ans_page) && isfield(ans_page, 'documents')
                 answer = ans_page.documents;
                 totalItems = 0;
                 if isfield(ans_page, 'totalItems')
                     totalItems = ans_page.totalItems;
                 elseif isfield(ans_page, 'number_matches')
                     totalItems = ans_page.number_matches;
                 end

                 % Calculate number of pages
                 numPages = ceil(double(totalItems) / this.pageSize);

                 % Loop through remaining pages
                 for p = 2:numPages
                     [b_page, ans_page, resp_page, url_page] = this.fetch_page(p);
                     apiURL(end+1) = url_page;
                     apiResponse(end+1) = resp_page;

                     if ~b_page
                         b = false;
                         break;
                     end

                     if isstruct(ans_page) && isfield(ans_page, 'documents')
                         new_docs = ans_page.documents;
                         if ~isempty(new_docs)
                            answer = cat(1, answer(:), new_docs(:));
                         end
                     end
                 end
            else
                 % Unexpected format or no documents
                 % If ans_page is empty or lacks documents, we assume empty result?
                 if isempty(answer)
                     answer = struct('id', {}, 'ndiId', {}, 'name', {}, 'className', {}, 'datasetId', {});
                 end
            end
        end
    end

    methods (Access = private)
        function [b, answer, apiResponse, apiURL] = fetch_page(this, page_num)
            b = false;
            answer = [];
            apiResponse = [];
            apiURL = [];

            for attempt = 1:this.retries
                api_call = ndi.cloud.api.implementation.documents.NdiQuery(...
                    'scope', this.scope, ...
                    'searchstructure', this.searchstructure, ...
                    'page', page_num, ...
                    'pageSize', this.pageSize);

                [b_page, ans_page, resp_page, url_page] = api_call.execute();

                if b_page
                    b = true;
                    answer = ans_page;
                    apiResponse = resp_page;
                    apiURL = url_page;
                    break;
                end
            end
        end
    end
end
