classdef ListFiles < ndi.cloud.api.call
%LISTFILES An implementation class for listing files in a cloud dataset.

    properties
        cloudDatasetId (1,1) string
    end

    methods
        function this = ListFiles(args)
            %LISTFILES Construct a new ListFiles object.
            arguments
                args.cloudDatasetId (1,1) string
            end
            this.cloudDatasetId = args.cloudDatasetId;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Calls the getDataset API and extracts file information.

            % Define the empty structure for the answer
            empty_answer = struct('uid', {}, 'isRaw', {}, 'uploaded', {}, ...
                                  'sourceDatasetId', {}, 'size', {});

            % Call the getDataset function
            [b, dsetInfo, apiResponse, apiURL] = ndi.cloud.api.datasets.getDataset(this.cloudDatasetId);

            if ~b
                % If the API call failed, return the error answer
                answer = dsetInfo;
                return;
            end

            % Check if the 'files' field exists and is not empty
            if isempty(dsetInfo) || ~isfield(dsetInfo, 'files') || isempty(dsetInfo.files)
                answer = empty_answer;
                return;
            end

            % If we have files, process them into the desired format
            numFiles = numel(dsetInfo.files);
            answer(numFiles) = struct('uid', [], 'isRaw', [], 'uploaded', [], ...
                                      'sourceDatasetId', [], 'size', []);

            for i = 1:numFiles
                file = dsetInfo.files(i);
                answer(i).uid = file.uid;
                answer(i).isRaw = file.isRaw;
                answer(i).uploaded = file.uploaded;
                answer(i).sourceDatasetId = file.sourceDatasetId;
                answer(i).size = file.size;
            end
        end
    end
end
