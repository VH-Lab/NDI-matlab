classdef ListFiles < ndi.cloud.api.call
%LISTFILES An implementation class for listing files in a cloud dataset.
%
%   Pages through the dataset's file list via the paginated
%   GET /datasets/{datasetId}/files endpoint, accumulating the pages into a
%   single de-duplicated list. Paging is required because a dataset can hold
%   tens of thousands of files; returning them all in one response (as the
%   legacy getDataset path did) can exceed the cloud API gateway's payload
%   limit and fail with a 502. For servers that predate the paginated
%   endpoint, execute() falls back to the single getDataset read.

    properties
        cloudDatasetId (1,1) string
        checkForUpdates (1,1) logical = true
        waitForUpdates (1,1) {mustBeNumeric} = 10
        maximumNumberUpdateReads (1,1) {mustBeNumeric} = 100
    end

    methods
        function this = ListFiles(args)
            %LISTFILES Construct a new ListFiles object.
            arguments
                args.cloudDatasetId (1,1) string
                args.checkForUpdates (1,1) logical = true
                args.waitForUpdates (1,1) {mustBeNumeric} = 10
                args.maximumNumberUpdateReads (1,1) {mustBeNumeric} = 100
                args.pageSize (1,1) {mustBeNumeric, mustBePositive} = 1000
            end
            this.cloudDatasetId = args.cloudDatasetId;
            this.checkForUpdates = args.checkForUpdates;
            this.waitForUpdates = args.waitForUpdates;
            this.maximumNumberUpdateReads = args.maximumNumberUpdateReads;
            % pageSize is inherited from ndi.cloud.api.call.
            this.pageSize = args.pageSize;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Pages through the dataset's files and returns them.

            % Define the empty structure for the answer
            empty_answer = struct('uid', {}, 'uploaded', {}, ...
                                  'sourceDatasetId', {}, 'size', {});

            fileMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            updateReads = 0;
            b = false;
            answer = empty_answer;
            apiResponse = [];
            apiURL = [];

            while true
                initialFileCount = fileMap.Count;

                % --- Full scan of the dataset's file list ---
                pageNumber = 1;
                totalNumber = Inf;   % unknown until the first page arrives
                usedLegacy = false;
                while true
                    [b, pageFiles, totalNumber, apiResponse, apiURL] = ...
                        this.fetchFilePage(pageNumber);

                    if ~b
                        % If the paginated endpoint is unavailable (older
                        % server), fall back to the legacy single getDataset
                        % read exactly once, then treat the scan as complete.
                        if pageNumber == 1 && ~isempty(apiResponse) && ...
                                apiResponse.StatusCode == 404
                            [b, legacyFiles, apiResponse, apiURL] = ...
                                this.fetchViaGetDataset();
                            if ~b
                                answer = empty_answer;
                                return;
                            end
                            this.accumulateFiles(fileMap, legacyFiles);
                            usedLegacy = true;
                            break;
                        end
                        % Any other failure: return the error response as-is.
                        answer = empty_answer;
                        return;
                    end

                    this.accumulateFiles(fileMap, pageFiles);

                    % Stop when we have seen every file the server reported, or
                    % when a page comes back empty (guards against a stale or
                    % inflated totalNumber causing an endless loop).
                    if isempty(pageFiles) || (pageNumber * this.pageSize) >= totalNumber
                        break;
                    end
                    pageNumber = pageNumber + 1;
                end

                % --- Optional re-poll to catch files added while we ran ---
                % (The legacy fallback has no cheap way to know the total, but
                % the count-comparison below still works for it.)
                if usedLegacy || ~this.checkForUpdates || fileMap.Count == initialFileCount
                    break;
                end

                updateReads = updateReads + 1;
                if updateReads >= this.maximumNumberUpdateReads
                    break;
                end
                pause(this.waitForUpdates);
            end

            if fileMap.Count == 0
                answer = empty_answer;
            else
                vals = values(fileMap);
                answer = [vals{:}]';
            end
        end
    end

    methods (Access = private)
        function [b, files, totalNumber, apiResponse, apiURL] = fetchFilePage(this, pageNumber)
            %FETCHFILEPAGE Retrieve a single page of the dataset's file list.
            b = false;
            files = {};
            totalNumber = 0;

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('list_dataset_files', ...
                'dataset_id', this.cloudDatasetId, ...
                'page', pageNumber, ...
                'page_size', this.pageSize);

            method = matlab.net.http.RequestMethod.GET;
            acceptField = matlab.net.http.HeaderField('accept', 'application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 200
                b = true;
                data = apiResponse.Body.Data;
                if ~isempty(data) && isfield(data, 'files') && ~isempty(data.files)
                    files = data.files;
                end
                if ~isempty(data) && isfield(data, 'totalNumber') && ~isempty(data.totalNumber)
                    totalNumber = data.totalNumber;
                else
                    totalNumber = numel(files);
                end
            end
        end

        function [b, files, apiResponse, apiURL] = fetchViaGetDataset(this)
            %FETCHVIAGETDATASET Legacy fallback: read the whole dataset once.
            files = {};
            [b, dsetInfo, apiResponse, apiURL] = ...
                ndi.cloud.api.datasets.getDataset(this.cloudDatasetId);
            if b && ~isempty(dsetInfo) && isfield(dsetInfo, 'files') && ~isempty(dsetInfo.files)
                files = dsetInfo.files;
            end
        end

        function accumulateFiles(~, fileMap, filesData)
            %ACCUMULATEFILES Add files to fileMap, de-duplicating by uid.
            %
            % jsondecode returns the files as a struct array when every entry
            % has the same field set, and as a cell array of structs when
            % entries have heterogeneous field sets. Both shapes are handled;
            % missing optional fields on a single entry (uploaded /
            % sourceDatasetId / size) are filled with defaults so one
            % weirdly-shaped server response cannot break the whole listing.
            % See VH-Lab/NDI-matlab#807.
            if isempty(filesData)
                return;
            end
            for i = 1:numel(filesData)
                if iscell(filesData)
                    file = filesData{i};
                else
                    file = filesData(i);
                end
                if ~isstruct(file) || ~isfield(file, 'uid') || isempty(file.uid)
                    continue;
                end
                if ~isKey(fileMap, file.uid)
                    entry = struct( ...
                        'uid', file.uid, ...
                        'uploaded', [], ...
                        'sourceDatasetId', '', ...
                        'size', []);
                    optionalFields = ["uploaded", "sourceDatasetId", "size"];
                    for k = 1:numel(optionalFields)
                        fname = char(optionalFields(k));
                        if isfield(file, fname)
                            entry.(fname) = file.(fname);
                        end
                    end
                    fileMap(file.uid) = entry;
                end
            end
        end
    end
end
