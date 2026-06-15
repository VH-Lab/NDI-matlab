classdef AdvanceSession < ndi.cloud.api.call
    %ADVANCESESSION Implementation class for advancing a compute session to the next stage.

    properties
        sessionId (1,1) string
    end

    methods
        function this = AdvanceSession(args)
            %ADVANCESESSION Creates a new AdvanceSession API call object.
            %
            %   THIS = ndi.cloud.api.implementation.compute.AdvanceSession('sessionId', ID)
            %
            %   Inputs:
            %       'sessionId' - The ID of the session to advance.
            %
            arguments
                args.sessionId (1,1) string
            end

            this.sessionId = args.sessionId;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to advance the session to the next stage.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('advance_compute_session', 'session_id', this.sessionId);

            method = matlab.net.http.RequestMethod.POST;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            % Send empty body to avoid warning "Expected a message using request method POST to have a Body."
            body = matlab.net.http.MessageBody([]);

            request = matlab.net.http.RequestMessage(method, headers, body);

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
