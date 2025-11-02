classdef ListDatasetDocuments < ndi.cloud.api.call
%LISTDATASETDOCUMENTS Implementation class for listing dataset documents.

    methods
        function this = ListDatasetDocuments(args)
            %LISTDATASETDOCUMENTS Creates a new ListDatasetDocuments API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.ListDatasetDocuments('cloudDatasetID', ID, 'page', P, 'pageSize', PS)
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
            %EXECUTE Performs the API call to list the documents.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('list_dataset_documents', ...
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

                % Standardize the output format
                answer = struct('id', {}, 'ndiId', {}, 'name', {}, 'className', {});

                if isfield(raw_answer, 'documents') && ~isempty(raw_answer.documents)
                    for i = 1:numel(raw_answer.documents)
                        doc = raw_answer.documents(i);

                        entry.id = doc.id;
                        entry.ndiId = doc.ndiDocument.id;
                        entry.className = doc.ndiDocument.document_class.class_name;

                        % Safely access the nested 'name' field
                        if isfield(doc.ndiDocument, 'document_properties') && ...
                           isfield(doc.ndiDocument.document_properties, 'base') && ...
                           isfield(doc.ndiDocument.document_properties.base, 'name')
                            entry.name = doc.ndiDocument.document_properties.base.name;
                        else
                            entry.name = '';
                        end

                        answer(end+1) = entry;
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

