classdef GetSignedURLSetAll < ndi.cloud.api.call
%GETSIGNEDURLSETALL Walk every page of a document's signed URL set.
%
%   Implementation behind ndi.cloud.api.files.getSignedURLSetAll. Calls
%   GetSignedURLSet repeatedly, following nextCursor until the server
%   reports no more pages, and merges the per-page `files` maps into a
%   single struct. A safety cap on the total number of pages prevents an
%   accidental unbounded walk.

    properties
        limit    (1,1) double
        maxPages (1,1) double
    end

    methods
        function this = GetSignedURLSetAll(args)
            arguments
                args.cloudDatasetID  (1,1) string
                args.cloudDocumentID (1,1) string
                args.limit           (1,1) double = 500
                args.maxPages        (1,1) double = 1000
            end
            this.cloudDatasetID  = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.limit    = args.limit;
            this.maxPages = args.maxPages;
            this.endpointName = 'get_signed_url_set';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            apiResponse = [];
            apiURL = [];

            cursor = "";
            merged = struct();
            merged.datasetId  = this.cloudDatasetID;
            merged.documentId = this.cloudDocumentID;
            merged.files      = struct();
            merged.pageCount  = 0;
            merged.totalCount = 0;
            merged.pages      = 0;

            for pageIdx = 1:this.maxPages
                [ok, page, apiResponse, apiURL] = ndi.cloud.api.files.getSignedURLSet(...
                    this.cloudDatasetID, this.cloudDocumentID, ...
                    'limit',  this.limit, ...
                    'cursor', cursor);
                if ~ok
                    answer = page;
                    return;
                end

                if isstruct(page) && isfield(page, 'files') && isstruct(page.files)
                    fnames = fieldnames(page.files);
                    for i = 1:numel(fnames)
                        merged.files.(fnames{i}) = page.files.(fnames{i});
                    end
                    merged.pageCount = merged.pageCount + numel(fnames);
                end
                if isstruct(page) && isfield(page, 'totalCount')
                    merged.totalCount = page.totalCount;
                end
                if isstruct(page) && isfield(page, 'expiresAt')
                    merged.expiresAt = page.expiresAt;
                end
                merged.pages = merged.pages + 1;

                % Terminate when the server signals no more pages: either
                % nextCursor is absent, missing (jsondecode -> []), or an
                % empty string.
                nextCursor = "";
                if isstruct(page) && isfield(page, 'nextCursor') && ~isempty(page.nextCursor)
                    try
                        nextCursor = string(page.nextCursor);
                    catch
                        nextCursor = "";
                    end
                end
                if strlength(nextCursor) == 0
                    b = true;
                    answer = merged;
                    return;
                end
                cursor = nextCursor;
            end

            % Ran off maxPages without a terminating page. Return partial
            % result with a flag so callers see it as a bounded failure
            % rather than success.
            b = false;
            merged.state = 'maxPagesReached';
            answer = merged;
        end
    end
end
