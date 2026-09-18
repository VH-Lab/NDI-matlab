classdef ListFiles < ndi.cloud.api.call
%LISTFILES An implementation class for listing files in a cloud dataset.

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
            end
            this.cloudDatasetId = args.cloudDatasetId;
            this.checkForUpdates = args.checkForUpdates;
            this.waitForUpdates = args.waitForUpdates;
            this.maximumNumberUpdateReads = args.maximumNumberUpdateReads;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Calls the getDataset API and extracts file information.

            % Define the empty structure for the answer
            empty_answer = struct('uid', {}, 'uploaded', {}, ...
                                  'sourceDatasetId', {}, 'size', {});

            fileMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            updateReads = 0;

            while updateReads < this.maximumNumberUpdateReads
                initialFileCount = fileMap.Count;

                % Call the getDataset function
                [b, dsetInfo, apiResponse, apiURL] = ndi.cloud.api.datasets.getDataset(this.cloudDatasetId);

                if ~b
                    % If the API call failed, return an empty answer and the error response
                    answer = empty_answer;
                    return;
                end

                % Check if the 'files' field exists and is not empty.
                % jsondecode returns dsetInfo.files as a struct array when
                % every entry has the same field set, and as a cell array of
                % structs when entries have heterogeneous field sets. The
                % loop tolerates both shapes; missing optional fields on a
                % single entry (uploaded / sourceDatasetId / size) are
                % filled with defaults so one weirdly-shaped server response
                % cannot break the whole listing. See VH-Lab/NDI-matlab#807.
                if ~isempty(dsetInfo) && isfield(dsetInfo, 'files') && ~isempty(dsetInfo.files)
                    for i = 1:numel(dsetInfo.files)
                        if iscell(dsetInfo.files)
                            file = dsetInfo.files{i};
                        else
                            file = dsetInfo.files(i);
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

                if ~this.checkForUpdates || fileMap.Count == initialFileCount
                    break;
                end

                pause(this.waitForUpdates);
                updateReads = updateReads + 1;
            end

            if fileMap.Count == 0
                answer = empty_answer;
            else
                vals = values(fileMap);
                answer = [vals{:}]';
            end
        end
    end
end
