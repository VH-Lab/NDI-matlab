function msg = APIMessage(narrative, b, answer, apiResponse, apiURL)
%APIMESSAGE - Create a pretty JSON string for API test diagnostics.
%
%   MSG = APIMESSAGE(NARRATIVE, B, ANSWER, APIRESPONSE, APIURL)
%
%   Creates a detailed diagnostic message string in JSON format.
%   It extracts only the serializable parts of the APIRESPONSE object to
%   avoid errors with jsonencode.
%
    reportStruct = struct();
    reportStruct.TestNarrative = narrative;
    reportStruct.APICallSuccessFlag = b;

    % Create a clean, non-recursive struct for the response details
    responseDetails = struct();
    if ~isempty(apiResponse) && isa(apiResponse,'matlab.net.http.ResponseMessage')
        responseDetails.StatusCode = string(apiResponse.StatusCode); % Convert enum to string
        responseDetails.StatusLine = apiResponse.StatusLine;
    else
        responseDetails.StatusCode = 'N/A';
        responseDetails.StatusLine = 'N/A - No valid API response object provided.';
    end
    
    reportStruct.APIResponseDetails = responseDetails;
    reportStruct.APICalledURL = apiURL;
    reportStruct.APIResponseBody = answer;
    
    msg = jsonencode(reportStruct, "PrettyPrint", true);
end

