function [b,msg] = download_dataset(email, password, dataset_id, output_path)
%DOWNLOAD_DATASET download the dataset from the server
%   
% [B, MSG] = ndi.cloud.download_dataset(EMAIL, PASSWORD, DATASET_ID, OUTPUT_PATH)
%
% Inputs:
%   EMAIL - The email address of the user
%   PASSWORD - The password of the user
%   DATASET_ID - The dataset ID to download
%   OUTPUT_PATH - The path to download the dataset to
%
% Outputs:
%   B - did the download work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''

msg = '';
b = 1;

verbose = 1;
[status, auth_token, organization_id] = ndi.cloud.auth.login(email, password);
if status 
    b = 0;
    msg = response;
    error(msg);
end
if verbose, disp(['Retrieving dataset...']); end

[status,dataset, response] = ndi.cloud.datasets.get_datasetId(dataset_id, auth_token);
if status 
    b = 0;
    msg = response;
    error(msg);
end

if verbose, disp(['Will download ' int2str(numel(dataset.documents)) ' documents...']); end

d = dataset.documents;

for i = 1:numel(d)
    if verbose, disp(['Downloading document ' int2str(i) ' of ' int2str(numel(d))  ' (' num2str(100*(i)/numel(d))  '%)' '...']); end
    document_id = d{i};
    [status, response, document] = ndi.cloud.documents.get_documents(dataset_id, document_id, auth_token);
    if status 
        b = 0;
        msg = response;
        error(msg);
    end
    if verbose, disp(['Saving document ' int2str(i) '...']); end

    %save the document in .json file
    json_file = [output_path filesep document_id '.json'];
    fid = fopen(json_file, 'w');
    fprintf(fid, '%s', did.datastructures.jsonencodenan(document));
    fclose(fid);
end

if verbose, disp(['Download complete.']); end
end

