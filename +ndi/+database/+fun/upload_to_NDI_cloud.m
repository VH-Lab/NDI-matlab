function [b, msg] = upload_to_NDI_cloud(S, dataset_id, varargin)
% UPLOAD_TO_NDI_CLOUD - upload an NDI database to NDI Cloud
%
% [B,MSG] = ndi.database.fun.upload_to_NDI_cloud(S, DATASET_ID, VARARGIN)
%
% Inputs:
%  S - an ndi.session object
%  DATASET_ID - the dataset id for the NDI Cloud
%
% Outputs:
%   B - did the upload work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''
%

verbose = 1;

did.datastructures.assign(varargin{:});
[auth_token, ~] = ndi.cloud.uilogin();

if verbose, disp(['Loading documents...']); end;
d = S.database_search(ndi.query('','isa','base'));

if verbose, disp(['Working on documents...']); end;

if verbose, disp(['Getting list of previously uploaded documents...']); end;
[doc_json_struct,doc_file_struct, total_size] = ndi.database.fun.scan_for_upload(S, d, 0, dataset_id);
%count the number of documents to be upload by checking the is_upload flag in doc_json_struct
docs_left = sum(~[doc_json_struct.is_uploaded]);
files_left = sum(~[doc_file_struct.is_uploaded]);
cur_size = 0;

doc_id_to_idx = containers.Map({doc_json_struct.docid}, 1:numel(doc_json_struct));
% file_id_to_idx = containers.Map({doc_file_struct.name}, 1:numel(doc_file_struct));
disp(['Found ' int2str(docs_left) ' new documents and ' int2str(files_left) ' files. Uploading...']);

msg = '';
b = 1;
cur_file_idx = 1;
cur_doc_idx = 1;
h_document = waitbar(0, 'Uploading Documents...');
h_file = waitbar(0, 'Uploading Files...');

for i=1:numel(d),
    % upload instruction - need to learn
    doc_id = d{i}.document_properties.base.id;
    if (~doc_json_struct(doc_id_to_idx(doc_id)).is_uploaded)
        document = did.datastructures.jsonencodenan(d{i}.document_properties);
        global ndi_globals;
        temp_dir = ndi_globals.path.temppath;
        ido_ = ndi.ido;
        rand_num = ido_.identifier;
        temp_filename = sprintf("file_%s.json", rand_num);
        path = fullfile(temp_dir,temp_filename);
        waitbar(cur_doc_idx/docs_left, h_document, sprintf('Uploading Document: %s. %d of %d...', doc_id, cur_doc_idx, docs_left));
        if verbose,
        disp(['Uploading ' int2str(cur_doc_idx) ' of ' int2str(docs_left) ' (' num2str(100*(cur_doc_idx)/docs_left)  '%)' ])
        end;
        [status, response_doc] = ndi.cloud.documents.post_documents(path, dataset_id, document, auth_token);
        if status ~= 0
            b = 0;
            msg = response_doc;
            error(msg);
        end
        doc_json_struct(doc_id_to_idx(doc_id)).is_uploaded = 1;
        cur_doc_idx = cur_doc_idx + 1;
    end

    % ndi_doc_id = d{index}.document_properties.base.id;

    if isfield(d{i}.document_properties, 'files'),
        doc_i = doc_i + 1;
        for f = 1:numel(d{i}.document_properties.files.file_list)
            file_name = d{i}.document_properties.files.file_list{f};
            waitbar(cur_file_idx/files_left, h_file, sprintf('Uploading file %d of %d, %.2f KB out of %.2f KB...', cur_file_idx, files_left, cur_size,total_size));

            if verbose, 
               disp(['Preparing to upload ' int2str(f) ' of ' int2str(numel(d{i}.document_properties.files.file_list)) ' binary files/sets (' file_name ')']);
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
                    file_obj = S.database_openbinarydoc(doc_id,filename_here);
                catch,
                    j = 1000000;
                    file_obj = [];
                end;
                j = j + 1;
                if ~isempty(file_obj),
                    if verbose, 
                       disp(['...Uploading ' int2str(f) ' of ' int2str(numel(d{i}.document_properties.files.file_list)) ' binary files/sets (' filename_here ')']);
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

        %if (numel(d{index}.document_properties.files.file_list) > 1)  % I don't understand this..I may have moved it  
        %    break;                                                     %  I think it breaks the document loop where I have it now 
        %end
    end

        % use whatever upload command is necessary
        % or, check to see if the file is already there?
end
delete(h_document);
delete(h_file);
end

