function [b, msg] = upload_to_NDI_cloud(S, auth_token, dataset_id, varargin)
% UPLOAD_TO_NDI_CLOUD - upload an NDI database to NDI Cloud
%
% [B,MSG] = ndi.database.fun.upload_to_NDI_cloud(S, AUTH_TOKEN, DATASET_ID, VARARGIN)
%
% Inputs:
%   S - an ndi.session object
%   AUTH_TOKEN - an upload token for NDI Cloud
%   DATASET_ID - the dataset id for the NDI Cloud
%
% Outputs:
%   B - did the upload work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''
%

% Step 1: find all the documents

doc_i = 1;
verbose = 1;

did.datastructures.assign(varargin{:});


if verbose, disp(['Loading documents...']); end;
d = S.database_search(ndi.query('','isa','base'));

if verbose, disp(['Working on documents...']); end;

% Step 3: loop over all the documents, uploading them to NDI Cloud
% q: do we do this all together, or one at a time?

if verbose, disp(['Getting list of previously uploaded documents...']); end;

[doc_status,doc_resp,doc_summary] = ndi.cloud.documents.get_documents_summary(dataset_id,auth_token);

already_uploaded_docs = {};
if numel(doc_resp.documents) > 0, already_uploaded_docs = {doc_resp.documents.ndiId}; end;

all_docs = {};
for i=1:numel(d),
	all_docs{i} = d{i}.document_properties.base.id;
end;

[ids_left,document_indexes_to_upload] = setdiff(all_docs, already_uploaded_docs);

if verbose, disp(['Found ' int2str(numel(already_uploaded_docs)) ' documents already uploaded...']); end;

if verbose, disp(['Will upload ' int2str(numel(document_indexes_to_upload)) ' documents ...']); end;

msg = '';
b = 1;
for i=1:numel(document_indexes_to_upload),
    % upload instruction - need to learn
    index = document_indexes_to_upload(i);
    document = did.datastructures.jsonencodenan(d{index}.document_properties);
    global ndi_globals;
    temp_dir = ndi_globals.path.temppath;
    ido_ = ndi.ido;
    rand_num = ido_.identifier;
    temp_filename = sprintf("file_%s.json", rand_num);
    path = fullfile(temp_dir,temp_filename);
    if verbose,
       disp(['Uploading ' int2str(i+numel(already_uploaded_docs)) ' of ' int2str(numel(d)) ' (' num2str(100*(i+numel(already_uploaded_docs))/numel(d))  '%)' ])
    end;
    [status, response_doc] = ndi.cloud.documents.post_documents(path, dataset_id, document, auth_token);
    if status ~= 0
        b = 0;
        msg = response_doc;
        error(msg);
    end

    ndi_doc_id = d{index}.document_properties.base.id;

    if isfield(d{index}.document_properties, 'files'),
        doc_i = doc_i + 1;
        if numel(d{index}.document_properties.files.file_list)>50, keyboard; end;
        for f = 1:numel(d{index}.document_properties.files.file_list)
            file_name = d{index}.document_properties.files.file_list{f};
            if verbose, 
               disp(['Uploading ' int2str(f) ' of ' int2str(numel(d{index}.document_properties.files.file_list)) ' binary files (' file_name ')']);
            end;
            j = 1;
            while j<10000, % we could potentially read a series of files
                if file_name(end)=='#', % this file is a series of files
                    filename_here = [file_name(1:end-1) int2str(j)];
                else,
                    filename_here = file_name;
                    j = 1000000; % only 1 file
                end;
                try,
                    file_obj = S.database_openbinarydoc(ndi_doc_id,filename_here);
                catch,
                    j = 1000000;
                    file_obj = [];
                end;
                if ~isempty(file_obj),
                if verbose, 
                   disp(['Uploading ' int2str(f) ' of ' int2str(numel(d{index}.document_properties.files.file_list)) ' binary files (' filename_here ')']);
                 end;
                    [~,uid,~] = fileparts(file_obj.fullpathfilename);
                    [status, response, upload_url] = ndi.cloud.files.get_files(dataset_id, uid, auth_token);
                    if status ~= 0
                        b = 0;
                        msg = response;
                        error(msg);
                    end
                    [status, response] = ndi.cloud.files.put_files(upload_url, file_obj.fullpathfilename, auth_token);
                    if status ~= 0
                        b = 0;
                        msg = response;
                        error(msg);
                    end
                    S.database_closebinarydoc(file_obj);
                end;
            end;            
        end

        if (numel(d{index}.document_properties.files.file_list) > 1)
            break;
        end
    end

    

        % use whatever upload command is necessary
        % or, check to see if the file is already there?
end
end

