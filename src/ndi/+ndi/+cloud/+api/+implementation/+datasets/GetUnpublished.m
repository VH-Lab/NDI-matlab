classdef GetUnpublished < ndi.cloud.api.call
%GETUNPUBLISHED Implementation class for getting unpublished datasets.

    methods
        function this = GetUnpublished(args)
            %GETUNPUBLISHED Creates a new GetUnpublished API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.GetUnpublished(...)
            %
            %   Optional Inputs (Name-Value Pairs):
            %       'page' - The page number of results to retrieve (default 1).
            %       'pageSize' - The number of results per page (default 20).
            %
            arguments
                args.page (1,1) double = 1
                args.pageSize (1,1) double = 20
            end
            
            this.page = args.page;
            this.pageSize = args.pageSize;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get unpublished datasets.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - The datasets struct on success, or error message on failure.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %
            
            % Initialize outputs
            b = false;
            answer = [];
            
            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('get_unpublished', 'page', this.page, 'page_size', this.pageSize);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

