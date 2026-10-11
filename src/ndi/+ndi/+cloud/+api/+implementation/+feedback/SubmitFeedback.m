classdef SubmitFeedback < ndi.cloud.api.call
    %SUBMITFEEDBACK Implements the API call to submit an in-app problem report.
    %
    %   Sends FEEDBACKSTRUCT as the JSON body of POST /feedback. The struct
    %   is sent as-is, so callers (and tests) can send any payload; use
    %   ndi.cloud.api.feedback.submitFeedback to build a valid one.
    %
    %   See also: ndi.cloud.api.feedback.submitFeedback

    properties
        feedbackStruct % The JSON body of the report
    end

    methods
        function this = SubmitFeedback(args)
            arguments
                args.feedbackStruct (1,1) struct
            end

            this.feedbackStruct = args.feedbackStruct;
            this.endpointName = "submit_feedback";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Performs the API call to submit a feedback report.
            %
            %   On success (201), ANSWER is the id of the stored report.

            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(this.feedbackStruct);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));

            auth_token = ndi.cloud.authenticate();
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);

            apiURL = ndi.cloud.api.url(this.endpointName);

            apiResponse = request.send(apiURL);

            if (apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data.id;
            else
                b = false;
                answer = [];
            end
        end
    end
end
