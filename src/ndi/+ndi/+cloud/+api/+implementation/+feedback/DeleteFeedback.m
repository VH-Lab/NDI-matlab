classdef DeleteFeedback < ndi.cloud.api.call
    %DELETEFEEDBACK Implements the API call to withdraw one of your own reports.
    %
    %   See also: ndi.cloud.api.feedback.deleteFeedback

    properties
        feedbackID (1,1) string
    end

    methods
        function this = DeleteFeedback(args)
            arguments
                args.feedbackID (1,1) string
            end

            this.feedbackID = args.feedbackID;
            this.endpointName = "delete_feedback";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Performs the API call to delete a feedback report.
            %
            %   The server answers 204 on success. A report that does not
            %   exist, or that belongs to another user, is answered with 404.

            method = matlab.net.http.RequestMethod.DELETE;

            auth_token = ndi.cloud.authenticate();
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiURL = ndi.cloud.api.url(this.endpointName, 'feedback_id', this.feedbackID);

            apiResponse = request.send(apiURL);

            if (apiResponse.StatusCode == 204)
                b = true;
                answer = 'Feedback deleted successfully.';
            else
                b = false;
                answer = [];
            end
        end
    end
end
