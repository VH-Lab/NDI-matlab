function [b, answer, apiResponse, apiURL] = documentClassCounts(cloudDatasetID)
%DOCUMENTCLASSCOUNTS User-facing wrapper to get a histogram of leaf class_name counts.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.documentClassCounts(CLOUDDATASETID)
%
%   Retrieves a flat histogram of documents in a dataset grouped by leaf
%   data.document_class.class_name via the 'document-class-counts'
%   endpoint. No inheritance roll-up is performed; for class-aware
%   drill-downs or listings, use ndiquery with the 'isa' operator.
%
%   Inputs:
%       cloudDatasetID - The ID of the dataset to query.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - On success, a struct with fields datasetId,
%                      totalDocuments, and classCounts (a struct whose
%                      fields are class names mapped to integer counts).
%                      Documents with missing/empty class_name are bucketed
%                      under 'unknown'. On failure, an error struct.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.documents.DocumentClassCounts

    arguments
        cloudDatasetID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.documents.DocumentClassCounts(...
        'cloudDatasetID', cloudDatasetID);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
