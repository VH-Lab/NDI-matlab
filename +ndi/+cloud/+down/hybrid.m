function [b,msg, D] = hybrid(dataset_id, output_path)
%HYBRID download document data but leave files in the cloud to be downloaded as requested
%   
% [B, MSG] = ndi.cloud.down.hybrid(DATASET_ID, [OUTPUT_PATH])
%
% Inputs:
%   DATASET_ID  - The dataset ID to download
%   OUTPUT_PATH - The path to download the dataset to. If not
%                 provided, the user will be prompted. 
%
% Outputs:
%   B - did the download work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''

msg = '';
b = 1;

if nargin<2,
	output_path = uigetdir(pwd,'Select a directory where the dataset should be placed...');

	if ~ischar(output_path),
		b = 0;
		msg = 'Cancelling per user request.';
		D = [];
	end;
end;

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

if ~isfolder([output_path filesep 'download' filesep 'json'])
    mkdir([output_path filesep 'download' filesep 'json']);
end

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

    document = ndi.cloud.down.set_file_info(document,'hybrid');

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

D = ndi.cloud.down.make_dataset_from_docs_files(output_path, [output_path filesep '.ndi' filesep 'reference.txt'],...
[output_path filesep 'download' filesep 'json'],[output_path filesep 'download' filesep 'files'] );

end

