function [b,msg, D] = download_dataset(dataset_id, output_path)
%DOWNLOAD_DATASET download the dataset from the server
%   
% [B, MSG] = ndi.cloud.download_dataset(DATASET_ID, OUTPUT_PATH)
%
% Inputs:
%   DATASET_ID - The dataset ID to download
%   OUTPUT_PATH - The path to download the dataset to
%
% Outputs:
%   B - did the download work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''

msg = '';
b = 1;

output_path = char(output_path);

verbose = 1;

if verbose, disp(['Retrieving dataset...']); end

[status,dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);
if status 
    b = 0;
    msg = response;
    error(msg);
end

%%Construct a new ndi.session
if ~isfolder(output_path)
    mkdir(output_path);
end

if ~isfolder([output_path filesep 'download' filesep 'files'])
    mkdir([output_path filesep 'download' filesep 'files']);
end

if ~isfolder([output_path filesep 'download' filesep 'json'])
    mkdir([output_path filesep 'download' filesep 'json']);
end

%%download the files
files = dataset.files;

if verbose, disp(['Will download ' int2str(numel(files)) ' files...']); end

files_map = containers.Map();

for i = 1:numel(files)
    if verbose, disp(['Downloading file ' int2str(i) ' of ' int2str(numel(files))  ' (' num2str(100*(i)/numel(files))  '%)' '...']); end
    file_uid = files(i).uid;
    uploaded = files(i).uploaded;
    files_map(file_uid) = uploaded;
    if ~uploaded
        disp('not uploaded to the cloud. Skipping...')
        continue;
    end
    file_path = [output_path filesep 'download' filesep 'files' filesep file_uid];
    if isfile(file_path)
        if verbose, disp(['File ' int2str(i) ' already exists. Skipping...']); end
        continue;
    end
    [~, ~, downloadURL, ~] = ndi.cloud.api.datasets.get_files_detail(dataset_id, file_uid);
    if verbose, disp(['Saving file ' int2str(i) '...']); end

    %save the file
    websave(file_path, downloadURL);
end
if verbose, disp(['File Downloading complete.']); end

if verbose, disp(['Will download ' int2str(numel(dataset.documents)) ' documents...']); end
d = dataset.documents;

for i = 1:numel(d)
    if verbose, disp(['Downloading document ' int2str(i) ' of ' int2str(numel(d))  ' (' num2str(100*(i)/numel(d))  '%)' '...']); end
    document_id = d{i};
    json_file_path = [output_path filesep 'download' filesep 'json' filesep document_id '.json'];
    if isfile(json_file_path)
        if verbose, disp(['Document ' int2str(i) ' already exists. Skipping...']); end
        continue;
    end

    [status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
    if status 
        b = 0;
        msg = response;
        error(msg);
    end
    if verbose, disp(['Saving document ' int2str(i) '...']); end

    document = rmfield(document, 'id');

    document_obj = ndi.document(document);
    %save the document in .json file
    fid = fopen(json_file_path, 'w');
    fprintf(fid, '%s', did.datastructures.jsonencodenan(document_obj));
    fclose(fid);
end

%Check if folder already exists
if ~isfolder([output_path filesep '.ndi'])
    mkdir([output_path filesep '.ndi']);
end

if ~isfolder([output_path filesep '.ndi' filesep 'json'])
    mkdir([output_path filesep '.ndi' filesep 'json']);
end

if ~isfolder([output_path filesep '.ndi' filesep 'files'])
    mkdir([output_path filesep '.ndi' filesep 'files']);
end

[status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, d{1});
session_id = document.base.id;
%%create a txt file with the session id
%check if file exist
if ~isfile(fullfile(output_path, filesep, '.ndi', 'reference.txt'))
    fid = fopen([output_path filesep '.ndi' filesep 'reference.txt'], 'w');
    fprintf(fid, '%s', session_id);
    fclose(fid);
end

D = ndi.cloud.fun.make_dataset_from_docs_files(output_path, [output_path filesep '.ndi' filesep 'reference.txt'],...
[output_path filesep 'download' filesep 'json'],[output_path filesep 'download' filesep 'files'] );

end

