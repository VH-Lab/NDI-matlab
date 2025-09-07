classdef ListDatasetDocumentsAll < ndi.cloud.api.call
%LISTDATASETDOCUMENTSALL Implementation class for listing ALL dataset documents.

    methods
        function this = ListDatasetDocumentsAll(args)
            %LISTDATASETDOCUMENTSALL Creates a new ListDatasetDocumentsAll call.
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %       'pageSize'       - (Optional) Results per page. Default 1000.
            %       'retries'        - (Optional) Retries per page. Default 10.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.pageSize (1,1) double = 1000
                args.retries (1,1) double = 10
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.pageSize = args.pageSize;
            this.endpointName = 'list_dataset_documents_all'; % Just for potential logging
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the paginated API calls to list all documents.
            
            % Initialize outputs
            b = true; % Assume success until a page fails
            answer = struct('documents',[]);
            apiResponse = []; % Will be the last successful response
            apiURL = [];      % Will be the last successful URL

            % 1. Get total number of documents to calculate pages
            [count_b, N] = ndi.cloud.api.documents.countDocuments(this.cloudDatasetID);
            if ~count_b
                b = false;
                answer = 'Failed to retrieve document count.';
                return;
            end
            
            if N == 0
                return; % Success, but no documents to fetch
            end

            numPages = ceil(double(N) / this.pageSize);

            % 2. Loop through all pages
            for p = 1:numPages
                page_succeeded = false;
                for attempt = 1:this.retries
                    
                    % Call the single-page lister
                    [page_b, page_summary, page_response, page_url] = ...
                        ndi.cloud.api.documents.listDatasetDocuments(...
                            this.cloudDatasetID, ...
                            'page', p, ...
                            'pageSize', this.pageSize);
                    
                    if page_b
                        % On success, append results and update response/URL
                        if isempty(answer.documents)
                            answer = page_summary;
                        else
                            answer.documents = cat(1, answer.documents, page_summary.documents);
                        end
                        apiResponse = page_response;
                        apiURL = page_url;
                        page_succeeded = true;
                        break; % Exit retry loop
                    end
                    % If it failed, the retry loop will continue
                end

                if ~page_succeeded
                    b = false; % Mark overall operation as failed
                    answer = sprintf('Failed to retrieve page %d for dataset %s after %d retries.', p, this.cloudDatasetID, this.retries);
                    break; % Exit the main page loop
                end
            end
        end
    end
end

