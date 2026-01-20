classdef StartSession < ndi.cloud.api.call
    %STARTSESSION Implementation class for starting a new compute session.

    properties
        pipelineId (1,1) string
        inputParameters (1,1) struct
    end

    methods
        function this = StartSession(args)
            %STARTSESSION Creates a new StartSession API call object.
            %
            %   THIS = ndi.cloud.api.implementation.compute.StartSession('pipelineId', ID, 'inputParameters', PARAMS)
            %
            %   Inputs:
            %       'pipelineId'      - The ID of the pipeline to start.
            %       'inputParameters' - (Optional) Structure containing input parameters.
            %
            arguments
                args.pipelineId (1,1) string
                args.inputParameters (1,1) struct = struct()
            end

            this.pipelineId = args.pipelineId;
            this.inputParameters = args.inputParameters;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to start the compute session.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('start_compute_session');

            method = matlab.net.http.RequestMethod.POST;

            requestBodyStruct = struct('pipelineId', this.pipelineId);
            if ~isempty(fieldnames(this.inputParameters))
                requestBodyStruct.inputParameters = this.inputParameters;
            end

            body = matlab.net.http.MessageBody(requestBodyStruct);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end
