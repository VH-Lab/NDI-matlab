classdef ListFilesAll < ndi.cloud.api.call
%LISTFILESALL Implementation class for retrieving all files in a dataset.
%   This class handles the paginated retrieval of every file summary from a
%   cloud dataset. It also includes an optional mechanism to check for and fetch
%   newly-added files that may appear while the initial list is being read.
%
%   Pagination is driven by the totalNumber reported by the files endpoint
%   (there is no separate file-count endpoint), obtained with a lightweight
%   single-record probe. This mirrors ListDatasetDocumentsAll's use of the
%   document-count endpoint.

    properties
        retries (1,1) double = 10
        checkForUpdates (1,1) logical = true
        waitForUpdates (1,1) double = 5
        maximumNumberUpdateReads (1,1) double = 100
    end

    methods
        function this = ListFilesAll(args)
            %LISTFILESALL Creates a new ListFilesAll API call object.
            %
            %   THIS = ndi.cloud.api.implementation.files.ListFilesAll('cloudDatasetID', ID, ...)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to query.
            %   Optional Name-Value Inputs:
            %       'pageSize'   - The number of results per page (default 1000).
            %       'retries'    - The number of times to retry a failed page read (default 10).
            %       'checkForUpdates' - Flag to enable checking for new files (default true).
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
            %EXECUTE Performs the API call to list all files.
            %   This method first determines the total number of files (and thus
            %   pages), then iterates through them, fetching each one using the
            %   private `fetch_and_append_page` helper method.
            %
            %   If `checkForUpdates` is true, it then enters a loop to re-check
            %   the total file count. If new files have been added, it fetches
            %   the new pages, de-duplicating results by uid. This continues
            %   until no new files are found or the `maximumNumberUpdateReads`
            %   limit is reached.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if all pages were read successfully, false otherwise.
            %       answer       - A struct array of file summaries on success, or an error struct.
            %       apiResponse  - An array of matlab.net.http.ResponseMessage objects from all page calls.
            %       apiURL       - An array of URLs that were called.
            %
            % Initialize outputs
            b = true;
            answer = struct('uid', {}, 'uploaded', {}, 'sourceDatasetId', {}, 'size', {});
            apiResponse = matlab.net.http.ResponseMessage.empty;
            apiURL = matlab.net.URI.empty;

            [b_count, numFiles] = this.fetchFileCount();

            currentTime = tic;

            if ~b_count
                b = false;
                answer = 'Could not determine file count.';
                return;
            end

            numPages = ceil(double(numFiles) / this.pageSize);
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
                elapsedTime = toc(currentTime); % make sure we waited at least this.waitForUpdates seconds
                if elapsedTime < this.waitForUpdates
                    pause(this.waitForUpdates-elapsedTime);
                end
                [b_count, newNumFiles] = this.fetchFileCount();
                while b_count && newNumFiles > numFiles && update_reads < this.maximumNumberUpdateReads

                    pause(this.waitForUpdates);
                    numFiles = newNumFiles;

                    start_page = max(1, last_page_read);

                    numPages = ceil(double(numFiles) / this.pageSize);
                    for p_update = start_page:numPages
                        [b_page, answer, apiResponse, apiURL] = this.fetch_and_append_page(p_update, answer, apiResponse, apiURL, true);
                        if ~b_page
                            b = false;
                            break;
                        end
                        last_page_read = p_update;
                    end
                    if ~b, break; end
                    update_reads = update_reads + 1;
                    [b_count, newNumFiles] = this.fetchFileCount();
                end
            end

        end
    end

    methods (Access = private)
        function [b, total] = fetchFileCount(this)
            %FETCHFILECOUNT Cheaply read the dataset's current total file count.
            %   There is no dedicated file-count endpoint, so this requests a
            %   single-record page and reads totalNumber from the response
            %   envelope.
            b = false;
            total = 0;
            [b_page, ~, resp_page, ~] = ndi.cloud.api.files.listFiles(...
                this.cloudDatasetID, 'page', 1, 'pageSize', 1);
            if b_page
                b = true;
                data = resp_page.Body.Data;
                if ~isempty(data) && isfield(data, 'totalNumber') && ~isempty(data.totalNumber)
                    total = double(data.totalNumber);
                end
            end
        end

        function [b, answer, apiResponse, apiURL] = fetch_and_append_page(this, page_num, answer, apiResponse, apiURL, deduplicate)
            %FETCH_AND_APPEND_PAGE Fetches a single page of files and appends them.
            %   This helper method is responsible for fetching a single page of
            %   file summaries. It handles the retry logic internally. If
            %   `deduplicate` is true, it will compare the uids of the fetched
            %   files with the existing files in `answer` and only append the
            %   new ones.
            b = false;
            for attempt = 1:this.retries
                [b_page, ans_page, resp_page, url_page] = ndi.cloud.api.files.listFiles(...
                    this.cloudDatasetID, 'page', page_num, 'pageSize', this.pageSize);

                apiURL(end+1) = url_page;
                apiResponse(end+1) = resp_page;

                if b_page
                    if isempty(answer)
                        answer = ans_page;
                    else
                        new_files = ans_page;
                        if ~isempty(new_files)
                            if deduplicate
                                existing_uids = string({answer.uid});
                                new_uids = string({new_files.uid});
                                [~, new_indices] = setdiff(new_uids, existing_uids);
                                if ~isempty(new_indices)
                                    answer = cat(1, answer(:), reshape(new_files(new_indices), [], 1));
                                end
                            else
                                answer = cat(1, answer(:), new_files(:));
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
