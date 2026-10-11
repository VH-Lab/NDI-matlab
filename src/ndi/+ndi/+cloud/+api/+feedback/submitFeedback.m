function [b, feedbackID, apiResponse, apiURL] = submitFeedback(app, category, description, options)
%SUBMITFEEDBACK User-facing wrapper to submit an in-app problem report to NDI Cloud.
%
%   [B, FEEDBACKID, APIRESPONSE, APIURL] = ndi.cloud.api.feedback.submitFeedback(APP, CATEGORY, DESCRIPTION, ...)
%
%   Sends a problem report to POST /feedback. The reporter is the
%   logged-in user. The server redacts anything that looks like a bearer
%   token or a signed S3 URL credential before storing the report, but
%   callers should still scrub logs before sending.
%
%   Inputs:
%       app         - Name of the client sending the report (e.g., "lightsheetZarr-viewer").
%       category    - One of "bug", "performance" or "other".
%       description - The user's free-text description of the problem.
%
%   Optional name-value inputs:
%       appVersion  - Version of the client (e.g., "NDI-matlab 2.0").
%       datasetId   - Cloud dataset id the report concerns.
%       documentId  - Document id the report concerns.
%       environment - Struct describing the client environment (os, versions, ...).
%       state       - Struct with client state useful for diagnosis.
%       log         - Recent log lines.
%       traceback   - Error stack, if any.
%
%   Server limits: 1 MB per request; description 20,000 characters, log
%   500,000, traceback 50,000; environment 20 kB and state 200 kB as JSON;
%   10 reports per user per hour.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       feedbackID  - The id of the stored report (use it with deleteFeedback).
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.feedback.deleteFeedback,
%             ndi.cloud.api.implementation.feedback.SubmitFeedback

    arguments
        app (1,1) string {mustBeNonzeroLengthText}
        category (1,1) string {mustBeMember(category, ["bug", "performance", "other"])}
        description (1,1) string {mustBeNonzeroLengthText}
        options.appVersion (1,1) string = missing
        options.datasetId (1,1) string = missing
        options.documentId (1,1) string = missing
        options.environment struct {mustBeScalarOrEmpty} = struct.empty
        options.state struct {mustBeScalarOrEmpty} = struct.empty
        options.log (1,1) string = missing
        options.traceback (1,1) string = missing
    end

    feedbackStruct = struct( ...
        'schemaVersion', 1, ...
        'app', app, ...
        'category', category, ...
        'description', description);

    stringFields = ["appVersion", "datasetId", "documentId", "log", "traceback"];
    for fieldName = stringFields
        if ~ismissing(options.(fieldName))
            feedbackStruct.(fieldName) = options.(fieldName);
        end
    end
    for fieldName = ["environment", "state"]
        if ~isempty(options.(fieldName))
            feedbackStruct.(fieldName) = options.(fieldName);
        end
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.feedback.SubmitFeedback('feedbackStruct', feedbackStruct);

    % 2. Call the execute method and return its outputs directly.
    [b, feedbackID, apiResponse, apiURL] = api_call.execute();

end
