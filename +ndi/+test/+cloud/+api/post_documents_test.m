function post_documents_test(dataset_id)
    %POST_DOCUMENTS_TEST - tests the api commands used to post documents
    %
    % POST_DOCUMENTS_TEST(dataset_id)
    %
    % Tests the following api commands:
    %
    %    datasets/post_documents
    %    documents/get_documents
    %    documents/post_documents_update
    %    files/get_files
    %    files/put_files
    %    files/get_files_detail

    % TODO: test scan_for_upload function. If correctly detects the number of files that have been uploaded
    dirname = [ndi.common.PathConstants.ExampleDataFolder filesep '..' filesep 'example_datasets' filesep 'sample_test'];

    D = ndi.dataset.dir(dirname);

    %% test scan_for_upload function

    d = D.database_search(ndi.query('','isa','base'));
    test_scan_for_upload(D, d, dataset_id, 0);

    %% test post_documents function
    test_post_documents(d, dataset_id);

    %% test scan_for_upload function again
    test_scan_for_upload(D, d, dataset_id, 1);

    %% test upload_to_NDI_cloud
    [b, msg] = ndi.cloud.up.upload_to_NDI_cloud(D, dataset_id);
    if ~b
        error(['ndi.cloud.up.upload_to_NDI_cloud() failed to upload the dataset' msg]);
    end

    [status, dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);

    %% test post_document_update
    test_document_update(dataset_id)

    try
        [status, response, document_id] = ndi.cloud.api.documents.post_documents('test', dataset_id, 'test');
        error('ndi.cloud.api.documents.post_documents did not throw an error after using a non-struct document');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response, document_id] = ndi.cloud.api.documents.get_documents(1, 1);
        error('ndi.cloud.api.documents.get_documents did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response] = ndi.cloud.api.documents.post_documents_update('test', dataset_id, 1, 'test');
        error('ndi.cloud.api.documents.post_documents_update did not throw an error after using an invalid document id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response] = ndi.cloud.api.files.get_files(1, 1);
        error('ndi.cloud.api.files.get_files did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response] = ndi.cloud.api.files.put_files('test', 'test');
        error('ndi.cloud.api.files.put_files did not throw an error after using an invalid url');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response] = ndi.cloud.api.files.get_files_detail(1, 1);
        error('ndi.cloud.api.files.get_files_detail did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
end

function test_scan_for_upload(D, d, dataset_id, n)
    % test scan_for_upload function
    % n is the number of documents that have been uploaded
    [doc_json_struct,doc_file_struct, total_size] = ndi.cloud.up.scan_for_upload(D, d, 0, dataset_id);
    docs_left = sum(~[doc_json_struct.is_uploaded]);
    files_left = sum(~[doc_file_struct.is_uploaded]);
    if docs_left ~= numel(doc_json_struct) - n
        error('Number of documents left to upload does not match the number of documents that have not been uploaded. Expected %d, got %d', numel(doc_json_struct) - n, docs_left);
    end
end

function test_post_documents(d, dataset_id)
    for i=1:numel(d)
        if isfield(d{i}.document_properties, 'files')
            continue;
        end
        document = did.datastructures.jsonencodenan(d{i}.document_properties);
        fname = ndi.file.temp_name();
        [status, response_doc, document_id] = ndi.cloud.api.documents.post_documents(fname, dataset_id, document);
        if status ~= 0
            error(response_doc);
        end
        [status, response, upload_document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
        if status
            error(response);
        end
        if ~isfield(upload_document, 'id')
            error('ndi.cloud.api.documents.get_documents does not return a document struct');
        end

        [status, dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);
        if numel(dataset.documents) ~= 1
            error('ndi.cloud.api.datasets.get_datasetId does not return the correct number of documents');
        end
        break;
    end
end

function test_post_files(S, d, dataset_id)
    for i=1:numel(d)
        doc_id = d{i}.document_properties.base.id;
        if isfield(d{i}.document_properties, 'files'),
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
                        file_obj = S.database_openbinarydoc(doc_id,filename_here);
                    catch,
                        j = 1000000;
                        file_obj = [];
                    end;
                    j = j + 1;
                    if ~isempty(file_obj),
                        [~,uid,~] = fileparts(file_obj.fullpathfilename);
                        [status, response, upload_url] = ndi.cloud.api.files.get_files(dataset_id, uid);
                        if status ~= 0
                            msg = response;
                            error(msg);
                        end
                        [status, response] = ndi.cloud.api.files.put_files(upload_url, file_obj.fullpathfilename);
                        if status ~= 0
                            msg = response;
                            error(msg);
                        end
                        S.database_closebinarydoc(file_obj);

                        [status,file_detail,downloadUrl, response] = ndi.cloud.api.files.get_files_detail(dataset_id,uid);
                        if status
                            error(response);
                        end
                        return;
                    end;
                end;
            end
        end
    end
end

function test_document_update(dataset_id)
    [status, response, summary] = ndi.cloud.api.documents.get_documents_summary(dataset_id);
    if status
        error(response);
    end
    document_id = summary.documents(1).id;
    [status, response, document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
    document.is_test = 1;
    document = jsonencode(document);
    [fid,fname] = ndi.file.temp_fid();
    [status, response] = ndi.cloud.api.documents.post_documents_update(fname, dataset_id, document_id, document);
    if status
        error(response);
    end
    [status, response, upload_document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
    if status
        error(response);
    end
    if ~isfield(upload_document, 'is_test') || ~upload_document.is_test
        error('ndi.cloud.api.documents.post_documents_update does not correctly update the document');
    end
    % change back to original
    % remove is_test field
    document = jsondecode(document);
    document = rmfield(document, 'is_test');
    document = jsonencode(document);
    [fid,fname] = ndi.file.temp_fid();
    [status, response] = ndi.cloud.api.documents.post_documents_update(fname, dataset_id, document_id, document);
    if status
        error(response);
    end
    [status, response, upload_document] = ndi.cloud.api.documents.get_documents(dataset_id, document_id);
    if status
        error(response);
    end
    if isfield(upload_document, 'is_test')
        error('ndi.cloud.api.documents.post_documents_update does not correctly update the document');
    end
end

