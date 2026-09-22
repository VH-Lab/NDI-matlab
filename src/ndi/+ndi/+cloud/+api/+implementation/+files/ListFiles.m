classdef ListFiles < ndi.cloud.api.call
%LISTFILES Implementation class for listing one page of a dataset's files.
%   Retrieves a single page from the paginated
%   GET /datasets/{datasetId}/files endpoint. Use
%   ndi.cloud.api.implementation.files.ListFilesAll to retrieve every page.

    methods
        function this = ListFiles(args)
            %LISTFILES Creates a new ListFiles API call object.
            %
            %   THIS = ndi.cloud.api.implementation.files.ListFiles('cloudDatasetID', ID, 'page', P, 'pageSize', PS)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %       'page'           - (Optional) The page number of results. Default is 1.
            %       'pageSize'       - (Optional) The number of results per page. Default is 1000.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.page (1,1) double = 1
                args.pageSize (1,1) double = 1000
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.page = args.page;
            this.pageSize = args.pageSize;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to list one page of files.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   On success ANSWER is a struct array of the page's files with
            %   fields uid, uploaded, sourceDatasetId, and size. The full page
            %   envelope (including totalNumber, page, and pageSize) is
            %   available in APIRESPONSE.Body.Data.

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('list_dataset_files', ...
                'dataset_id', this.cloudDatasetID, ...
                'page', this.page, ...
                'page_size', this.pageSize);

            method = matlab.net.http.RequestMethod.GET;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                raw_answer = apiResponse.Body.Data;

                % Standardize the output format.
                answer = struct('uid', {}, 'uploaded', {}, 'sourceDatasetId', {}, 'size', {});

                if ~isempty(raw_answer) && isfield(raw_answer, 'files') && ~isempty(raw_answer.files)
                    files_from_api = raw_answer.files;
                    % jsondecode returns files as a struct array when every
                    % entry has the same field set, and as a cell array of
                    % structs when entries have heterogeneous field sets. Both
                    % shapes are handled; missing optional fields on a single
                    % entry are filled with defaults so one weirdly-shaped
                    % entry cannot break the whole page. See VH-Lab/NDI-matlab#807.
                    for i = 1:numel(files_from_api)
                        if iscell(files_from_api)
                            file_in = files_from_api{i};
                        else
                            file_in = files_from_api(i);
                        end

                        if ~isstruct(file_in) || ~isfield(file_in, 'uid') || isempty(file_in.uid)
                            continue;
                        end

                        file_out = struct( ...
                            'uid', file_in.uid, ...
                            'uploaded', [], ...
                            'sourceDatasetId', '', ...
                            'size', []);

                        if isfield(file_in, 'uploaded')
                            file_out.uploaded = file_in.uploaded;
                        end
                        if isfield(file_in, 'sourceDatasetId')
                            file_out.sourceDatasetId = file_in.sourceDatasetId;
                        end
                        if isfield(file_in, 'size')
                            file_out.size = file_in.size;
                        end

                        answer(end+1) = file_out;
                    end
                end
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end
end
