classdef GetSignedURLSetAll < ndi.cloud.api.call
%GETSIGNEDURLSETALL Pages through the signed URL set and merges it into one map.
%
%   Repeatedly calls ndi.cloud.api.documents.getSignedURLSet, following
%   nextCursor until the server reports no more pages, and returns the union as
%   a single containers.Map. This is the shape a viewer wants: one resident
%   hashmap giving O(1) uid -> URL lookup while panning a pyramid level.
%
%   For sets large enough that paging is slow, prefer the asynchronous job
%   (ndi.cloud.api.documents.createSignedURLSetJob), which has the server build
%   the whole map once and hand back a single gzipped blob.

    properties
        limit (1,1) double = 500
        fileSeries (1,1) string = ""
        maxPages (1,1) double = Inf
    end

    methods
        function this = GetSignedURLSetAll(args)
            %GETSIGNEDURLSETALL Creates a new GetSignedURLSetAll call.
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentID (1,1) string
                args.limit (1,1) double {mustBePositive, mustBeInteger} = 500
                args.fileSeries (1,1) string = ""
                args.maxPages (1,1) double {mustBePositive} = Inf
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.limit = args.limit;
            this.fileSeries = args.fileSeries;
            this.maxPages = args.maxPages;
            this.endpointName = 'get_signed_url_set';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Pages through the whole set.
            %
            %   Outputs:
            %       b      - True if every page succeeded.
            %       answer - On success, a struct with fields:
            %                  files     - containers.Map, the merged set
            %                  pages     - number of pages fetched
            %                  expiresAt - expiry reported by the last page
            %                  complete  - true if the server ran out of pages,
            %                              false if maxPages stopped us early
            %                On failure, the error body from the failing page.
            %       apiResponse - The ResponseMessage from the last page fetched.
            %       apiURL      - The URL of the last page fetched.

            % The loop below always runs at least once, so apiResponse, apiURL
            % and expiresAt are assigned by the first page rather than here.
            b = false;

            files = containers.Map('KeyType','char','ValueType','any');
            cursor = "";
            pages = 0;
            complete = false;

            while true
                [ok, pageAnswer, apiResponse, apiURL] = ...
                    ndi.cloud.api.documents.getSignedURLSet(...
                        this.cloudDatasetID, this.cloudDocumentID, ...
                        'limit', this.limit, ...
                        'cursor', cursor, ...
                        'fileSeries', this.fileSeries);

                if ~ok
                    answer = pageAnswer;
                    return
                end

                pages = pages + 1;
                expiresAt = pageAnswer.expiresAt;

                pageKeys = keys(pageAnswer.files);
                for i = 1:numel(pageKeys)
                    files(pageKeys{i}) = pageAnswer.files(pageKeys{i});
                end

                if isempty(pageAnswer.nextCursor)
                    complete = true;
                    break
                end
                if pages >= this.maxPages
                    break
                end
                if strcmp(pageAnswer.nextCursor, char(cursor))
                    % The server handed back the cursor we just used. Following
                    % it would page forever; stop rather than hang.
                    error('NDI:CloudApi:SignedURLSet:CursorDidNotAdvance', ...
                        ['The signed URL set cursor did not advance after page ' ...
                        '%d. Refusing to page forever.'], pages);
                end
                cursor = string(pageAnswer.nextCursor);
            end

            b = true;
            answer = struct('files', files, 'pages', pages, ...
                'expiresAt', expiresAt, 'complete', complete);
        end
    end
end
