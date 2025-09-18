function [b, msg] = upload_to_NDI_cloud(S, dataset_id, varargin)
    % UPLOAD_TO_NDI_CLOUD - upload an NDI database to NDI Cloud
    %
    % [B,MSG] = ndi.cloud.upload.upload_to_NDI_cloud(S, DATASET_ID, VARARGIN)
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

    if verbose, disp(['Loading documents...']); end
    d = S.database_search(ndi.query('','isa','base'));

    if verbose, disp(['Working on documents...']); end

    if verbose, disp(['Getting list of previously uploaded documents...']); end
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

    for i=1:numel(d)
        % upload instruction - need to learn
        doc_id = d{i}.document_properties.base.id;
        if (~doc_json_struct(doc_id_to_idx(doc_id)).is_uploaded)
            document = did.datastructures.jsonencodenan(d{i}.document_properties);
            waitbar(cur_doc_idx/docs_left, h_document, sprintf('Uploading Document: %s. %d of %d...', doc_id, cur_doc_idx, docs_left));
            if verbose
                disp(['Uploading ' int2str(cur_doc_idx) ' JSON portions of ' int2str(docs_left) ' (' num2str(100*(cur_doc_idx)/docs_left)  '%)' ])
            end
            [success, ~] = ndi.cloud.api.documents.addDocumentAsFile(dataset_id, document);
            if ~success, warning('Failed to add document'); end
            doc_json_struct(doc_id_to_idx(doc_id)).is_uploaded = 1;
            cur_doc_idx = cur_doc_idx + 1;
        end
    end
    delete(h_document);

    [b, msg] = ndi.cloud.upload.zip_for_upload(S, doc_file_struct, total_size, dataset_id);
end
