function downloadUrl = get_bulk_download_url(dataset_id, document_ids)
    % get_bulk_download_url - Get URL for downloading documents in bulk
    %
    % downloadUrl = get_bulk_download_url(dataset_id) returns a signed url to
    %   download a zip file containing all the json files containing document
    %   data (as a root-level array) for the specified dataset
    %
    % downloadUrl = get_bulk_download_url(dataset_id, document_ids) returns a 
    %   signed url to download a zip file containing a subset of documents for
    %   the specified dataset. The document_ids is a string array of
    %   document ids (NB: cloud ids, not NDI ids) representing documents to
    %   download.
    %
    % Inputs:
    %   dataset_id - string representing a dataset id
    %   document_ids - string array 
    %
    % Outputs:
    %   downloadUrl - string representing a download url
    
    arguments
        dataset_id (1,1) string
        document_ids (1,:) string
    end

    api_url = ndi.cloud.api.url('bulk_download_documents', 'dataset_id', dataset_id);
    opts = ndi.cloud.internal.get_weboptions_with_auth_header();
    % Note: If document_ids is "", the resulting download url will yield
    % all the documents of a dataset.
    data = struct('documentIds', document_ids);

    result = webwrite(api_url, data, opts);

    downloadUrl = result.url;
end
