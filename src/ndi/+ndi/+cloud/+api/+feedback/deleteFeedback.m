function [b, answer, apiResponse, apiURL] = deleteFeedback(feedbackID)
%DELETEFEEDBACK User-facing wrapper to withdraw one of your own problem reports.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.feedback.deleteFeedback(FEEDBACKID)
%
%   Deletes a report previously sent with ndi.cloud.api.feedback.submitFeedback.
%   Only the user who submitted a report can delete it; any other report
%   (or one that does not exist) is answered with 404.
%
%   Inputs:
%       feedbackID - The id returned by submitFeedback.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - A confirmation message on success.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.feedback.submitFeedback,
%             ndi.cloud.api.implementation.feedback.DeleteFeedback

    arguments
        feedbackID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.feedback.DeleteFeedback('feedbackID', feedbackID);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
