classdef ListDatasetDocumentsAll < ndi.cloud.api.call
%LISTDATASETDOCUMENTSALL Implementation class for retrieving all documents in a dataset.
    properties
        retries (1,1) double = 10
    end

    methods
        function this = ListDatasetDocumentsAll(args)
            %LISTDATASETDOCUMENTSALL Creates a new ListDatasetDocumentsAll API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.ListDatasetDocumentsAll('cloudDatasetID', ID, ...)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to query.
            %   Optional Name-Value Inputs:
            %       'pageSize'   - The number of results per page (default 1000).
            %       'retries'    - The number of times to retry a failed page read (default 10).
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.pageSize (1,1) double = 1000
                args.retries (1,1) double = 10
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.pageSize = args.pageSize;
            this.retries = args.retries;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to list all documents.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if all pages were read successfully, false otherwise.
            %       answer       - A struct with a 'documents' field containing all summaries, or an error struct.
            %       apiResponse  - An array of matlab.net.http.ResponseMessage objects from all page calls.
            %       apiURL       - An array of URLs that were called.
            %
            % Initialize outputs
            b = true;
            answer = struct('documents',[]);
            apiResponse = matlab.net.http.ResponseMessage.empty;
            apiURL = matlab.net.URI.empty;

            [b_count, numDocs, ~, ~] = ndi.cloud.api.documents.documentCount(this.cloudDatasetID);

            if ~b_count
                b = false;
                answer = 'Could not determine document count.';
                return;
            end
        
            numPages = ceil(double(numDocs) / this.pageSize);

            for p = 1:numPages
                page_succeeded = false;
                for attempt = 1:this.retries
                    [b_page, ans_page, resp_page, url_page] = ndi.cloud.api.documents.listDatasetDocuments(...
                        this.cloudDatasetID, 'page', p, 'pageSize', this.pageSize);
                    
                    apiURL(end+1) = url_page;
                    apiResponse(end+1) = resp_page;

                    if b_page
                        if isempty(answer.documents)
                            answer = ans_page;
                        else
                            answer.documents = cat(1, answer.documents, ans_page.documents);
                        end
                        page_succeeded = true;
                        break; % Exit retry loop on success
                    end
                end

                if ~page_succeeded
                    b = false; % Mark overall operation as failed
                    break; % Exit the main page loop
                end
            end
        end
    end
end

