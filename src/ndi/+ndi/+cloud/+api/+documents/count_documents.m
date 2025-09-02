function [N] = count_documents(cloudDatasetId, options)
    % COUNT_DOCUMNETS - Get a count of the number of documents in a dataset
    %
    % [N] = COUNT_DOCUMENTS(cloudDatasetId, options)
    %
    % Returns the number of documents N in a dataset.
    %
    % Inputs:
    %   cloudDatasetId - (1,1) string
    %                    A string representing the dataset id as it exists on the cloud.
    %   options.datasetInfo - (1,1) struct
    %                      If the user already has a document structure,
    %                      this can be passed to save a API call
    %
    % Outputs:
    %   N        - (1,1) uint32
    %              The number of documents in the dataset
    %
    
    arguments
        cloudDatasetId (1,1) string
        options.datasetInfo (1,:) struct = []
    end

    if ~isempty(options.datasetInfo)
        datasetInfo = options.datasetInfo;
    else
        datasetInfo = ndi.cloud.api.datasets.get_dataset(cloudDatasetId);
    end

    if isfield(datasetInfo,'documentCount')
        N = uint32(datasetInfo.documentCount);
        if N==0 % check for legacy version
            if isfield(datasetInfo,"documents")
                N = N + uint32(numel(datasetInfo.documents));
            end
        end
    elseif isfield(datasetInfo,'documents') % legacy
        N = uint32(numel(datasetInfo.documents));
    else
        error(['Unable to determine number of documents for dataset ' cloudDatasetId '.']);
    end
    
end