classdef AbortSession < ndi.cloud.api.call
    %ABORTSESSION Implementation class for aborting a compute session.

    properties
        sessionId (1,1) string
    end

    methods
        function this = AbortSession(args)
            %ABORTSESSION Creates a new AbortSession API call object.
            %
            %   THIS = ndi.cloud.api.implementation.compute.AbortSession('sessionId', ID)
            %
            %   Inputs:
            %       'sessionId' - The ID of the session to abort.
            %
            arguments
                args.sessionId (1,1) string
            end

            this.sessionId = args.sessionId;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to abort the session.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('abort_compute_session', 'session_id', this.sessionId);

            method = matlab.net.http.RequestMethod.DELETE;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 204)
                b = true;
                answer = []; % No content
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end
