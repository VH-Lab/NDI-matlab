classdef TriggerStage < ndi.cloud.api.call
    %TRIGGERSTAGE Implementation class for triggering a stage in a compute session.

    properties
        sessionId (1,1) string
        stageId (1,1) string
    end

    methods
        function this = TriggerStage(args)
            %TRIGGERSTAGE Creates a new TriggerStage API call object.
            %
            %   THIS = ndi.cloud.api.implementation.compute.TriggerStage('sessionId', SID, 'stageId', STID)
            %
            %   Inputs:
            %       'sessionId' - The ID of the session.
            %       'stageId'   - The ID of the stage to trigger.
            %
            arguments
                args.sessionId (1,1) string
                args.stageId (1,1) string
            end

            this.sessionId = args.sessionId;
            this.stageId = args.stageId;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to trigger the stage.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('trigger_compute_stage', 'session_id', this.sessionId, 'stage_id', this.stageId);

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
