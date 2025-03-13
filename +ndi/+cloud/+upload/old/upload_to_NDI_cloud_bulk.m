function [b, msg] = upload_to_NDI_cloud_bulk(S, dataset_id, varargin)
    % upload_to_NDI_cloud_bulk - upload an NDI database to NDI Cloud
    %
    % [B,MSG] = ndi.database.fun.upload_to_NDI_cloud_bulk(S, DATASET_ID, VARARGIN)
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

    vlt.data.assign(varargin{:});

    if verbose, disp(['Loading documents...']); end;
    d = S.database_search(ndi.query('','isa','base'));

    if verbose, disp(['Working on documents...']); end;

    if verbose, disp(['Getting list of previously uploaded documents...']); end;
    [doc_json_struct,doc_file_struct, total_size] = ndi.cloud.upload.scan_for_upload(S, d, 0, dataset_id);
    % count the number of documents to be upload by checking the is_upload flag in doc_json_struct
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
            waitbar(cur_doc_idx/docs_left, h_document, sprintf('Uploading Document: %s. %d of %d...', doc_id, cur_doc_idx, docs_left));
            if verbose,
                disp(['Uploading ' int2str(cur_doc_idx) ' of ' int2str(docs_left) ' (' num2str(100*(cur_doc_idx)/docs_left)  '%)' ])
            end;
            [response_doc] = ndi.cloud.api.documents.add_document_as_file(dataset_id, document);
            doc_json_struct(doc_id_to_idx(doc_id)).is_uploaded = 1;
            cur_doc_idx = cur_doc_idx + 1;
        end
    end

    % zip the files
    if verbose, disp(['Zipping files...']); end;
    zip_filename = [ndi.common.PathConstants.TempFolder filesep 'files.zip'];
    path = [S.path filesep '.ndi' filesep 'files' filesep];
    files_to_zip = {};
    file_idx = 1;
    for i = 1:length(doc_file_struct)
        if ~doc_file_struct(i).is_uploaded
            file_path = fullfile(path, doc_file_struct(1).uid);
            files_to_zip{file_idx} = file_path;
            file_idx = file_idx + 1;
        end
    end

    zip(zip_filename, files_to_zip);
    [response, upload_url] = ndi.cloud.api.datasets.get_file_collection_upload_url(dataset_id);
    [response] = ndi.cloud.api.files.put_files(upload_url, zip_filename);
    if exist(zip_filename, 'file')
        delete(zip_filename);
    end
    delete(zip_filename);
    delete(h_document);
    delete(h_file);
end
