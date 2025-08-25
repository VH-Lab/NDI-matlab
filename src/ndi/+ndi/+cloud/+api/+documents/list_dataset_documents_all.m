function [b, summary] = list_dataset_documents_all(cloudDatasetId, options)
    % LIST_DATASET_DOCUMENTS_ALL - Get summaries for ALL documents in a dataset.
    %
    % [b, summary] = list_dataset_documents_all(cloudDatasetId, options)
    % This function retrieves all document summaries from a dataset by making repeated
    % paginated calls to ndi.cloud.api.documents.list_dataset_documents.
    %
    % Inputs:
    %   cloudDatasetId - (1,1) string
    %                    A string representing the dataset id as it exists on the cloud.
    %   options.pageSize - (1,1) double
    %                      The number of results to retrieve per page.
    %                      Defaults to 1000.
    %   options.retries - (1,1) double
    %                     The number of times to retry a failed page read
    %                     before giving up. Defaults to 10.
    %
    % Outputs:
    %   b        - (1,1) logical
    %              True if all pages were read successfully (retries are okay),
    %              false if any page failed after all retry attempts.
    %   summary  - (:,1) struct array
    %              A struct array containing the concatenated list of document
    %              summaries from all successful page reads.
    %
    
    arguments
        cloudDatasetId (1,1) string
        options.pageSize (1,1) double = 1000
        options.retries (1,1) double = 10
    end

    % Initialize outputs
    b = true;
    summary = [];

    datasetInfo = ndi.cloud.api.datasets.get_dataset(cloudDatasetId);
    % TODO: Replace this placeholder with the actual call to get the document count
    numberOfDocuments = 201500; 
    
    numPages = ceil(numberOfDocuments / options.pageSize);

    for p = 1:numPages
        page_succeeded = false;
        for attempt = 1:options.retries
            try
                [~, page_summary] = ndi.cloud.api.documents.list_dataset_documents(...
                    cloudDatasetId, ...
                    'page', p, ...
                    'pageSize', options.pageSize);
                
                if isempty(summary)
                    summary = page_summary;
                else
                    summary = struct('documents',cat(1,summary.documents,page_summary.documents));
                end
                page_succeeded = true;
                break; % Exit retry loop on success
            catch
                % Let the retry loop continue on failure
            end
        end

        if ~page_succeeded
            b = false; % Mark overall operation as failed
            warning('Failed to retrieve page %d for dataset %s after %d retries.', p, cloudDatasetId, options.retries);
            break; % Exit the main page loop
        end
    end
end
