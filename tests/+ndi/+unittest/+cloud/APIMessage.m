function msg = APIMessage(narrative, APICallSuccessFlag, APIResponseBody, apiResponse, apiURL)
% APIMESSAGE - Create a detailed, pretty-printed JSON message for test diagnostics.
%
%   MSG = APIMESSAGE(NARRATIVE, APICALLSUCCESSFLAG, APIRESPONSEBODY, APIRESPONSE, APIURL)
%
%   Formats the inputs into a structured report that is easy to read in test logs,
%   especially for non-MATLAB developers. It robustly handles complex or non-serializable
%   objects in the API response.
%
    arguments
        narrative (1,:) string
        APICallSuccessFlag (1,1) logical
        APIResponseBody
        apiResponse
        apiURL
    end

    reportStruct = struct();
    reportStruct.TestNarrative = narrative;
    reportStruct.APICallSuccessFlag = APICallSuccessFlag;

    % Create a clean, serializable struct for the response details
    responseDetails = struct();
    if isa(apiResponse, 'matlab.net.http.ResponseMessage')
        if isempty(apiResponse)
            responseDetails.StatusCode = "NONE - empty";
            responseDetails.StatusLine = "NONE - empty";
        else
            responseDetails.StatusCode = char(apiResponse.StatusCode);
            responseDetails.StatusLine = apiResponse.StatusLine;
        end
    else
        responseDetails.ResponseObject = 'Not a standard HTTP ResponseMessage';
    end
    reportStruct.APIResponseDetails = responseDetails;
    
    reportStruct.APICalledURL = string(apiURL);

    % Robustly handle the APIResponseBody, which might not be JSON
    if isstruct(APIResponseBody) || ischar(APIResponseBody) || isstring(APIResponseBody) || isnumeric(APIResponseBody) || islogical(APIResponseBody) || iscell(APIResponseBody)
        % It's already JSON-friendly or a simple value
        reportStruct.APIResponseBody = APIResponseBody;
    elseif isa(APIResponseBody, 'org.apache.xerces.dom.DeferredDocumentImpl')
        % It's an XML DOM object from a PUT response, convert it to a string
        try
            reportStruct.APIResponseBody = xmlwrite(APIResponseBody);
        catch
            reportStruct.APIResponseBody = 'Received an XML Document that could not be converted to string.';
        end
    else
        % Catch-all for other non-serializable types
        reportStruct.APIResponseBody = ['Unsupported data type for JSON encoding: ' class(APIResponseBody)];
    end

    msg = jsonencode(reportStruct, "PrettyPrint", true);
end
