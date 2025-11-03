classdef ListDatasetDocumentsAll < ndi.cloud.api.call
%LISTDATASETDOCUMENTSALL Implementation class for retrieving all documents in a dataset.
%   This class handles the paginated retrieval of all document summaries from a
%   cloud dataset. It also includes an optional mechanism to check for and fetch
%   newly-added documents that may appear while the initial list is being read.
%
    properties
        retries (1,1) double = 10
        checkForUpdates (1,1) logical = true
        waitForUpdates (1,1) double = 5
        maximumNumberUpdateReads (1,1) double = 100
    end

    methods
        function this = ListDatasetDocumentsAll(args)
            %LISTDATASETDOCUMENTSALL Creates a new ListDatasetDocumentsAll API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.ListDatasetDocumentsAll('cloudDatasetID', ID, ...)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to query.
            %   Optional Name-Value Inputs:
            %       'pageSize'   - The number of results per page (default 1000).
            %       'retries'    - The number of times to retry a failed page read (default 10).
            %       'checkForUpdates' - Flag to enable checking for new documents (default true).
            %       'waitForUpdates'  - Pause duration in seconds before re-checking (default 5).
            %       'maximumNumberUpdateReads' - Limit on update re-polls (default 100).
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.pageSize (1,1) double = 1000
                args.retries (1,1) double = 10
                args.checkForUpdates (1,1) logical = true
                args.waitForUpdates (1,1) double = 5
                args.maximumNumberUpdateReads (1,1) double = 100
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.pageSize = args.pageSize;
            this.retries = args.retries;
            this.checkForUpdates = args.checkForUpdates;
            this.waitForUpdates = args.waitForUpdates;
            this.maximumNumberUpdateReads = args.maximumNumberUpdateReads;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to list all documents.
            %   This method first determines the total number of pages and then iterates
            %   through them, fetching each one using the private `fetch_and_append_page`
            %   helper method.
            %
            %   If `checkForUpdates` is true, it then enters a loop to re-check the
            %   total document count. If new documents have been added, it fetches
            %   the new pages, de-duplicating results to ensure no duplicates are
            %   added. This continues until no new documents are found or the
            %   `maximumNumberUpdateReads` limit is reached.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if all pages were read successfully, false otherwise.
            %       answer       - A struct array of document summaries on success, or an error struct.
            %       apiResponse  - An array of matlab.net.http.ResponseMessage objects from all page calls.
            %       apiURL       - An array of URLs that were called.
            %
            % Initialize outputs
            b = true;
            answer = struct('id', {}, 'ndiId', {}, 'name', {}, 'className', {});
            apiResponse = matlab.net.http.ResponseMessage.empty;
            apiURL = matlab.net.URI.empty;

            [b_count, numDocs, ~, ~] = ndi.cloud.api.documents.documentCount(this.cloudDatasetID);

            if ~b_count
                b = false;
                answer = 'Could not determine document count.';
                return;
            end
        
            numPages = ceil(double(numDocs) / this.pageSize);
            last_page_read = 0;

            for p = 1:numPages
                [b_page, answer, apiResponse, apiURL] = this.fetch_and_append_page(p, answer, apiResponse, apiURL, false);
                if ~b_page
                    b = false;
                    break;
                end
                last_page_read = p;
            end

            if this.checkForUpdates && b
                update_reads = 0;
                [b_count, newNumDocs, ~, ~] = ndi.cloud.api.documents.documentCount(this.cloudDatasetID);
                while b_count && newNumDocs > numDocs && update_reads < this.maximumNumberUpdateReads
                    pause(this.waitForUpdates);
                    numDocs = newNumDocs;

                    start_page = max(1, last_page_read);

                    numPages = ceil(double(numDocs) / this.pageSize);
                    for p_update = start_page:numPages
                        [b_page, answer, apiResponse, apiURL] = this.fetch_and_append_page(p_update, answer, apiResponse, apiURL, true);
                        if ~b_page
                            b = false;
                            break;
                        end
                        last_page_read = p_update;
                    end
                    if ~b, break; end;
                    update_reads = update_reads + 1;
                    [b_count, newNumDocs, ~, ~] = ndi.cloud.api.documents.documentCount(this.cloudDatasetID);
                end
            end

        end
    end

    methods (Access = private)
        function [b, answer, apiResponse, apiURL] = fetch_and_append_page(this, page_num, answer, apiResponse, apiURL, deduplicate)
            %FETCH_AND_APPEND_PAGE Fetches a single page of documents and appends them.
            %   This helper method is responsible for fetching a single page of document
            %   summaries. It handles the retry logic internally. If `deduplicate` is
            %   true, it will compare the IDs of the fetched documents with the
            %   existing documents in `answer` and only append the new ones.
            b = false;
            for attempt = 1:this.retries
                [b_page, ans_page, resp_page, url_page] = ndi.cloud.api.documents.listDatasetDocuments(...
                    this.cloudDatasetID, 'page', page_num, 'pageSize', this.pageSize);

                apiURL(end+1) = url_page;
                apiResponse(end+1) = resp_page;

                if b_page
                    if isempty(answer)
                        answer = ans_page;
                    else
                        new_docs = ans_page;
                        if ~isempty(new_docs)
                            if deduplicate
                                existing_ids = string({answer.id});
                                new_ids = string({new_docs.id});
                                [~, new_indices] = setdiff(new_ids, existing_ids);
                                if ~isempty(new_indices)
                                    answer = cat(1, answer(:), new_docs(new_indices));
                                end
                            else
                                answer = cat(1, answer(:), new_docs(:));
                            end
                        end
                    end
                    b = true;
                    break; % Exit retry loop on success
                end
            end
        end
    end
end
