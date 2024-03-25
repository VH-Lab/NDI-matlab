function [doc_json_struct,doc_file_struct, total_size] = scan_for_upload(S, new, dataset_id)
%SCAN_FOR_UPLOAD - Scans the session for documents and files to upload. Calculate the size of the files.
%   
% [DOC_JSON_STRUCT,DOC_FILE_STRUCT] = ndi.database.fun.scan_for_upload(S, DATASET_ID)
%  
% Inputs:
%  S - an ndi.session object
%  NEW - 1 if this is a new dataset with empty documents and files, 0 otherwise
%  DATASET_ID - The dataset id. dataset_id = '' if it is a new dataset
%
% Outputs:
%  DOC_JSON_STRUCT - A structure with the following fields:
%    'docid' - The document id
%    'is_uploaded' - A flag indicating if the document is uploaded
%  DOC_FILE_STRUCT - A structure with the following fields:
%    'uid' - The uid of the file
%    'name' - The name of the file
%    'docid' - The document id that the file is associated with
%    'bytes' - The size of the file in bytes
%    'is_uploaded' - A flag indicating if the file is uploaded
%  TOTAL_SIZE - The total size of the files to upload in KB

verbose = 1;
[auth_token, organization_id] = ndi.cloud.uilogin();

if verbose, disp(['Loading documents...']); end;
    
d = S.database_search(ndi.query('','isa','base'));
all_docs = {};
clear doc_json_struct;
clear doc_file_struct;
doc_json_struct = struct('docid',{},'is_uploaded', {});
doc_file_struct = struct('name',{},'docid',{},'bytes',{},'is_uploaded', {});
total_size = 0;

for i=1:numel(d)
disp(['Working on document ' int2str(i) ' of ' int2str(numel(d))])
    all_docs{i} = d{i}.document_properties.base.id;
    doc_json_struct(i).docid = d{i}.document_properties.base.id;
    doc_json_struct(i).is_uploaded = false;
    if isfield(d{i}.document_properties, 'files')
        for f = 1:numel(d{i}.document_properties.files.file_list)
            file_name = d{i}.document_properties.files.file_list{f};
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
                j = j + 1;
                if ~isempty(file_obj),
                    curr_idx = numel(doc_file_struct)+1;
                    [~,uid,~] = fileparts(file_obj.fullpathfilename);
                    doc_file_struct(curr_idx).uid = uid;
                    doc_file_struct(curr_idx).name = file_name;
                    doc_file_struct(curr_idx).docid = d{i}.document_properties.base.id;
                    file_info = dir(file_obj.fullpathfilename);
                    file_size= file_info.bytes / 1024;
                    doc_file_struct(curr_idx).bytes = file_size;
                    total_size = file_size + total_size;
                    doc_file_struct(curr_idx).is_uploaded = false;
                end;
            end;
        end
    end
end


if (~new)
    keyboard
    [doc_status,doc_resp,doc_summary] = ndi.cloud.documents.get_documents_summary(dataset_id,auth_token);
    [status,dataset, response] = ndi.cloud.datasets.get_datasetId(dataset_id, auth_token);
    already_uploaded_docs = {};
    if numel(doc_resp.documents) > 0, already_uploaded_docs = {doc_resp.documents.ndiId}; end;
    [ids_left,document_indexes_to_upload] = setdiff(all_docs, already_uploaded_docs);
    docid_upload = containers.Map(all_docs(document_indexes_to_upload),  repmat({1}, 1, numel(document_indexes_to_upload)));
    for i = 1:numel(doc_json_struct)
        if (~isKey(docid_upload, doc_json_struct(i).docid))
            doc_json_struct(i).is_uploaded = true;
        end
    end
    %create a map contains dataset.files.uid as key and uploaded as value
    file_map = containers.Map;
    for i = 1:numel(dataset.files)
        file_map(dataset.files(i).uid) = dataset.files(i).uploaded;
    end
    for i = 1:numel(doc_file_struct)
        if (isKey(file_map, doc_file_struct(i).uid))
            doc_file_struct(i).is_uploaded = file_map(doc_file_struct(i).uid);
            if (doc_file_struct(i).is_uploaded)
                total_size = total_size - doc_file_struct(i).bytes;
            end
        end
    end
end

