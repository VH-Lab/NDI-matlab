function [b, msg] = upload_to_NDI_cloud(S, email, password, dataset_id, varargin)
% UPLOAD_TO_NDI_CLOUD - upload an NDI database to NDI Cloud
%
% [B,MSG] = ndi.database.fun.upload_to_NDI_cloud(S, EMAIL, PASSWORD)
%
% Inputs:
%   S - an ndi.session object
%   TOKEN - an upload token for NDI Cloud
%
% Outputs:
%   B - did the upload work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''
%

% Step 1: find all the documents


verbose = 1;

did.datastructures.assign(varargin{:});


if verbose, disp(['Loading documents...']); end;
d = S.database_search(ndi.query('','isa','base'));

if verbose, disp(['Logging in...']); end;
[auth_token, organization_id] = ndi.cloud.auth.login(email, password);

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
% for i=1:numel(document_indexes_to_upload),
    % upload instruction - need to learn
    index = document_indexes_to_upload(i);
    document = did.datastructures.jsonencodenan(d{index}.document_properties);
%     document = jsonencode(d{index}.document_properties);
    global ndi_globals;
    temp_dir = ndi_globals.path.temppath;
    ido_ = ndi.ido;
    rand_num = ido_.identifier;
    temp_filename = sprintf("file_%s.json", rand_num);
    path = fullfile(temp_dir,temp_filename);
    if verbose,
       disp(['Uploading ' int2str(i+numel(already_uploaded_docs)) ' of ' int2str(numel(d)) ' (' num2str(100*(i+numel(already_uploaded_docs))/numel(d))  '%)' ])
    end;
    [status, response] = ndi.cloud.documents.post_documents(path, dataset_id, document, auth_token);
    if status ~= 0
        b = 0;
        msg = response;
        error(msg);
    end

    ndi_doc_id = d{index}.document_properties.base.id;

    if isfield(d{index}.document_properties, 'files'),
        for f = 1:numel(d{index}.document_properties.files.file_list)
            file_name = d{index}.document_properties.files.file_list{f};
            if verbose, 
               disp(['Uploading ' int2str(f) ' of ' int2str(numel(d{index}.document_properties.files.file_list)) ' binary files (' file_name ')']);
            end;
            file_obj = S.database_openbinarydoc(ndi_doc_id, file_name);
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
        end
    end

   
        % use whatever upload command is necessary
        % or, check to see if the file is already there?
end
end

