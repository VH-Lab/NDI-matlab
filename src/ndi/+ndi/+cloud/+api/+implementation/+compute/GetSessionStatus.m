classdef GetSessionStatus < ndi.cloud.api.call
    %GETSESSIONSTATUS Implementation class for getting the status of a compute session.

    properties
        sessionId (1,1) string
    end

    methods
        function this = GetSessionStatus(args)
            %GETSESSIONSTATUS Creates a new GetSessionStatus API call object.
            %
            %   THIS = ndi.cloud.api.implementation.compute.GetSessionStatus('sessionId', ID)
            %
            %   Inputs:
            %       'sessionId' - The ID of the session to check.
            %
            arguments
                args.sessionId (1,1) string
            end

            this.sessionId = args.sessionId;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get the session status.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('get_compute_session', 'session_id', this.sessionId);

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
