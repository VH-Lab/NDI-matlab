function msg = formatApiError(apiResponse)
% FORMATAPIERROR - Build a human-readable error message from an HTTP response.
%
%   MSG = ndi.cloud.internal.formatApiError(APIRESPONSE)
%
%   Returns a non-empty char message describing the failed API call. Tolerates
%   APIRESPONSE being empty, missing a body, or having a body that is not a
%   struct with a 'message' field (the conditions that caused #624).

    if isempty(apiResponse) || ~isa(apiResponse, 'matlab.net.http.ResponseMessage')
        msg = 'no response from server';
        return;
    end

    statusPart = '';
    try
        statusPart = sprintf('HTTP %d', double(apiResponse.StatusCode));
        if ~isempty(apiResponse.StatusLine) && ~isempty(apiResponse.StatusLine.ReasonPhrase)
            statusPart = sprintf('%s %s', statusPart, char(apiResponse.StatusLine.ReasonPhrase));
        end
    catch
    end

    bodyPart = '';
    try
        data = apiResponse.Body.Data;
        if isstruct(data) && isfield(data, 'message') && ~isempty(data.message)
            bodyPart = char(string(data.message));
        elseif isstruct(data) && isfield(data, 'error') && ~isempty(data.error)
            bodyPart = char(string(data.error));
        elseif ischar(data) || isstring(data)
            bodyPart = char(string(data));
        end
    catch
    end

    if ~isempty(statusPart) && ~isempty(bodyPart)
        msg = sprintf('%s - %s', statusPart, bodyPart);
    elseif ~isempty(statusPart)
        msg = statusPart;
    elseif ~isempty(bodyPart)
        msg = bodyPart;
    else
        msg = 'unknown error';
    end
end
