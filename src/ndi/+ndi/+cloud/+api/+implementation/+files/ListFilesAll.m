classdef ListFilesAll < ndi.cloud.api.call
%LISTFILESALL Implementation class for retrieving all files in a dataset.
%   Retrieves every file summary from a cloud dataset by following the keyset
%   cursor returned by the files endpoint. It also includes an optional
%   mechanism to check for and fetch newly-added files that may appear while
%   the initial list is being read.
%
%   Keyset pagination (a cursor on insertion order) is used instead of
%   page/offset: it is O(1) per page at any depth and stable under concurrent
%   writes, and it lets an update poll resume from the last cursor to pick up
%   files appended while the scan ran.

    properties
        limit (1,1) double = 1000
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
            %       'limit'      - Max results fetched per page (default 1000).
            %       'retries'    - Times to retry a failed page read (default 10).
            %       'checkForUpdates' - Check for new files after the first scan (default true).
            %       'waitForUpdates'  - Pause seconds before re-checking (default 5).
            %       'maximumNumberUpdateReads' - Limit on update re-polls (default 100).
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.limit (1,1) double = 1000
                args.retries (1,1) double = 10
                args.checkForUpdates (1,1) logical = true
                args.waitForUpdates (1,1) double = 5
                args.maximumNumberUpdateReads (1,1) double = 100
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.limit = args.limit;
            this.retries = args.retries;
            this.checkForUpdates = args.checkForUpdates;
            this.waitForUpdates = args.waitForUpdates;
            this.maximumNumberUpdateReads = args.maximumNumberUpdateReads;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Follows the keyset cursor to list all files.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if all pages were read successfully, false otherwise.
            %       answer       - A struct array of file summaries (uid, uploaded,
            %                      sourceDatasetId, size) on success.
            %       apiResponse  - An array of matlab.net.http.ResponseMessage objects from all page calls.
            %       apiURL       - An array of URLs that were called.

            % Initialize outputs
            b = true;
            answer = struct('uid', {}, 'uploaded', {}, 'sourceDatasetId', {}, 'size', {});
            apiResponse = matlab.net.http.ResponseMessage.empty;
            apiURL = matlab.net.URI.empty;

            % lastCursor is the resume token (cursor of the last page seen). An
            % update poll resumes from it to pick up files appended since.
            lastCursor = "";

            % --- Initial full scan ---
            after = "";
            while true
                [b_page, answer, apiResponse, apiURL, cursor, hasMore] = ...
                    this.fetch_and_append_page(after, answer, apiResponse, apiURL, true);
                if ~b_page
                    b = false;
                    return;
                end
                if strlength(cursor) > 0
                    lastCursor = cursor;
                end
                if hasMore
                    after = cursor;
                else
                    break;
                end
            end

            % --- Optional re-poll to catch files added while we ran ---
            if this.checkForUpdates
                update_reads = 0;
                while update_reads < this.maximumNumberUpdateReads
                    pause(this.waitForUpdates);
                    countBefore = numel(answer);

                    after = lastCursor;
                    while true
                        [b_page, answer, apiResponse, apiURL, cursor, hasMore] = ...
                            this.fetch_and_append_page(after, answer, apiResponse, apiURL, true);
                        if ~b_page
                            b = false;
                            break;
                        end
                        if strlength(cursor) > 0
                            lastCursor = cursor;
                        end
                        if hasMore
                            after = cursor;
                        else
                            break;
                        end
                    end

                    if ~b
                        break;
                    end
                    update_reads = update_reads + 1;
                    if numel(answer) == countBefore
                        break; % nothing new was added
                    end
                end
            end
        end
    end

    methods (Access = private)
        function [b, answer, apiResponse, apiURL, cursor, hasMore] = fetch_and_append_page(this, afterCursor, answer, apiResponse, apiURL, deduplicate)
            %FETCH_AND_APPEND_PAGE Fetch one keyset page and append its files.
            %   Handles retry logic. If `deduplicate` is true, only files whose
            %   uid is not already present are appended. Returns the page's
            %   cursor (resume token) and hasMore flag from the response envelope.
            b = false;
            cursor = "";
            hasMore = false;
            for attempt = 1:this.retries
                [b_page, ans_page, resp_page, url_page] = ndi.cloud.api.files.listFiles(...
                    this.cloudDatasetID, 'limit', this.limit, 'after', afterCursor);

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

                    % Read the keyset envelope from the raw response.
                    data = resp_page.Body.Data;
                    if ~isempty(data) && isfield(data, 'cursor') && ~isempty(data.cursor) ...
                            && (ischar(data.cursor) || isstring(data.cursor))
                        cursor = string(data.cursor);
                    end
                    if ~isempty(data) && isfield(data, 'hasMore') && ~isempty(data.hasMore)
                        hasMore = logical(data.hasMore);
                    end

                    b = true;
                    break; % Exit retry loop on success
                end
            end
        end
    end
end
