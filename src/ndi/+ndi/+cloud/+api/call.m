classdef (Abstract) call < handle
    %CALL An abstract interface for all NDI cloud API calls.
    %   Ensures that all API call implementations have an 'execute' method
    %   with a consistent signature for handling success and failure.

    properties
        % Common API parameters, initialized to 'missing'
        cloudOrganizationID = missing;
        cloudDatasetID      = missing;
        cloudFileID         = missing;
        cloudUserID         = missing;
        cloudDocumentID     = missing;
        page                = missing;
        pageSize            = missing;
        endpointName        = missing;
    end

    methods (Abstract)
        % EXECUTE - Performs the API call.
        %
        %   Outputs:
        %       b           - A logical (true/false) indicating if the call succeeded.
        %       answer      - The data payload from the API. Empty on failure.
        %       apiResponse - The full matlab.net.http.ResponseMessage object.
        %       apiURL      - The URL that was called.
        %
        [b, answer, apiResponse, apiURL] = execute(this)
    end
    
end


