function add_document_test(dataset_id)
    %ADD_DOCUMENT_TEST - tests the api commands used to post documents
    %
    % ADD_DOCUMENT_TEST(dataset_id)
    %
    % Tests the following api commands:
    %
    %    datasets/add_document
    %    documents/get_document
    %    documents/update_document
    %    files/get_file_upload_url
    %    files/put_files
    %    files/get_file_details

    % TODO: test scan_for_upload function. If correctly detects the number of files that have been uploaded
    dirname = [ndi.common.PathConstants.ExampleDataFolder filesep '..' filesep 'example_datasets' filesep 'sample_test'];

    D = ndi.dataset.dir(dirname);

    %% test scan_for_upload function

    d = D.database_search(ndi.query('','isa','base'));
    test_scan_for_upload(D, d, dataset_id, 0);

    %% test add_document function
    test_add_document(d, dataset_id);

    %% test scan_for_upload function again
    test_scan_for_upload(D, d, dataset_id, 1);

    %% test upload_to_NDI_cloud
    [b, msg] = ndi.cloud.upload.upload_to_NDI_cloud(D, dataset_id);
    if ~b
        error(['ndi.cloud.upload.upload_to_NDI_cloud() failed to upload the dataset' msg]);
    end

    [dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);

    %% test post_document_update
    test_document_update(dataset_id)

    try
        [response, document_id] = ndi.cloud.api.documents.add_document_as_file(dataset_id, 'test');
        error('ndi.cloud.api.documents.add_document did not throw an error after using a non-struct document');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [response, document_id] = ndi.cloud.api.documents.get_document(1, 1);
        error('ndi.cloud.api.documents.get_document did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        response = ndi.cloud.api.documents.update_document('test', dataset_id, 1, 'test');
        error('ndi.cloud.api.documents.update_document did not throw an error after using an invalid document id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        response = ndi.cloud.api.files.get_file_upload_url(1, 1);
        error('ndi.cloud.api.files.get_file_upload_url did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        response = ndi.cloud.api.files.put_files('test', 'test');
        error('ndi.cloud.api.files.put_files did not throw an error after using an invalid url');
    catch
        % do nothing, this is the expected behavior
    end
    try
        response = ndi.cloud.api.files.get_file_details(1, 1);
        error('ndi.cloud.api.files.get_file_details did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
end

function test_scan_for_upload(D, d, dataset_id, n)
    % test_scan_for_upload function
    % n is the number of documents that have been uploaded
    [doc_json_struct,doc_file_struct, total_size] = ndi.cloud.upload.scan_for_upload(D, d, 0, dataset_id);
    docs_left = sum(~[doc_json_struct.is_uploaded]);
    files_left = sum(~[doc_file_struct.is_uploaded]);
    if docs_left ~= numel(doc_json_struct) - n
        error('Number of documents left to upload does not match the number of documents that have not been uploaded. Expected %d, got %d', numel(doc_json_struct) - n, docs_left);
    end
end

function test_add_document(d, dataset_id)
    for i=1:numel(d)
        if isfield(d{i}.document_properties, 'files')
            continue;
        end
        document = did.datastructures.jsonencodenan(d{i}.document_properties);
        [~, document_id] = ndi.cloud.api.documents.add_document_as_file(dataset_id, document);
        [~, upload_document] = ndi.cloud.api.documents.get_document(dataset_id, document_id);

        if ~isfield(upload_document, 'id')
            error('ndi.cloud.api.documents.get_document does not return a document struct');
        end

        [dataset, ~] = ndi.cloud.api.datasets.get_dataset(dataset_id);
        if numel(dataset.documents) ~= 1
            error('ndi.cloud.api.datasets.get_dataset does not return the correct number of documents');
        end
        break;
    end
end

function test_post_files(S, d, dataset_id)
    for i=1:numel(d)
        doc_id = d{i}.document_properties.base.id;
        if isfield(d{i}.document_properties, 'files')
            for f = 1:numel(d{i}.document_properties.files.file_list)
                file_name = d{i}.document_properties.files.file_list{f};
                j = 1;
                while j<10000 % we could potentially read a series of files
                    if file_name(end)=='#' % this file is a series of files
                        filename_here = [file_name(1:end-1) int2str(j)];
                    else
                        filename_here = file_name;
                        j = 1000000; % only 1 file
                    end
                    try
                        file_obj = S.database_openbinarydoc(doc_id,filename_here);
                    catch
                        j = 1000000;
                        file_obj = [];
                    end
                    j = j + 1;
                    if ~isempty(file_obj)
                        [~,uid,~] = fileparts(file_obj.fullpathfilename);
                        [response, upload_url] = ndi.cloud.api.files.get_file_upload_url(dataset_id, uid);
                        response = ndi.cloud.api.files.put_files(upload_url, file_obj.fullpathfilename);
                        S.database_closebinarydoc(file_obj);

                        [file_detail, downloadUrl, response] = ndi.cloud.api.files.get_file_details(dataset_id,uid);
                        return;
                    end
                end
            end
        end
    end
end

function test_document_update(dataset_id)
    [response, summary] = ndi.cloud.api.documents.list_dataset_documents(dataset_id);
    document_id = summary.documents(1).id;
    [response, document] = ndi.cloud.api.documents.get_document(dataset_id, document_id);
    document.is_test = 1;
    document = jsonencode(document);
    [fid,fname] = ndi.file.temp_fid();
    response = ndi.cloud.api.documents.update_document(fname, dataset_id, document_id, document);
    [response, upload_document] = ndi.cloud.api.documents.get_document(dataset_id, document_id);
    if ~isfield(upload_document, 'is_test') || ~upload_document.is_test
        error('ndi.cloud.api.documents.update_document does not correctly update the document');
    end
    % change back to original
    % remove is_test field
    document = jsondecode(document);
    document = rmfield(document, 'is_test');
    document = jsonencode(document);
    [fid,fname] = ndi.file.temp_fid();
    response = ndi.cloud.api.documents.update_document(fname, dataset_id, document_id, document);
    [response, upload_document] = ndi.cloud.api.documents.get_document(dataset_id, document_id);
    if isfield(upload_document, 'is_test')
        error('ndi.cloud.api.documents.update_document does not correctly update the document');
    end
end
