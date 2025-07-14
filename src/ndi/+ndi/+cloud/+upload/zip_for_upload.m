function [b, msg] = zip_for_upload(D, doc_file_struct, total_size, dataset_id)
    % ZIP_FOR_UPLOAD - Create a zip file for uploading to the NDI cloud
    %   [B, MSG] = ndi.cloud.upload.ZIP_FOR_UPLOAD(D, DOC_FILE_STRUCT, TOTAL_SIZE, DATASET_ID)
    %
    % Inputs:
    %  D - the ndi.database object
    %  DOC_FILE_STRUCT - A structure with the following fields:
    %  'uid' - The uid of the file
    %  'name' - The name of the file
    %  'docid' - The document id that the file is associated with
    %  'bytes' - The size of the file in bytes
    %  'is_uploaded' - A flag indicating if the file is uploaded
    %  TOTAL_SIZE - The total size of the files to be uploaded
    %  DATASET_ID - The dataset id
    %
    % Outputs:
    %   B - did the upload work? 0 for no, 1 for yes
    %   MSG - An error message if the upload failed; otherwise ''

    verbose = 1;
    msg = '';
    b = 1;
    h = waitbar(0, 'Uploading Files...');
    files_left = sum(~[doc_file_struct.is_uploaded]);
    % set the maximum size of the zip file to be 5GB
    size_limit = 1e8;
    cur_size = 0;
    files_to_zip = {};
    dir = [D.path filesep '.ndi' filesep 'files' filesep];
    file_count = 0;
    uploaded_size = 0;
    % total_size from kb to GB
    total_size = total_size/1e6;
    for i = 1:numel(doc_file_struct)
        if doc_file_struct(i).is_uploaded
            continue;
        end
        file_count = file_count + 1;
        file_path = fullfile(dir, doc_file_struct(i).uid);
        if isfile(file_path)
            if cur_size + doc_file_struct(i).bytes > size_limit
                files_to_zip{end+1} = file_path;
                zip_file = [ndi.file.temp_name() '.zip'];
                zip(zip_file, files_to_zip);
                cur_size = cur_size + doc_file_struct(i).bytes;
                size_gb = cur_size/1e9;
                uploaded_size = uploaded_size + size_gb;
                if verbose
                    disp(['Zipping ' int2str(numel(files_to_zip)) ' binary files for upload.' num2str(size_gb,2) ' GB in total ' ])
                end
                try
                    waitbar(file_count/files_left, h, sprintf('Uploading file %d of %d. Size %.2f GB out of %.2f GB...', file_count, files_left, uploaded_size, total_size));
                catch
                end
                [response, upload_url] = ndi.cloud.api.datasets.get_file_collection_upload_url(dataset_id)
                [response] = ndi.cloud.api.files.put_files(upload_url, zip_file)

                if isfile(zip_file)
                    delete(zip_file);
                end
                % reset the size
                cur_size = 0;
                files_to_zip = {};
            else
                files_to_zip{end+1} = file_path;
                cur_size = cur_size + doc_file_struct(i).bytes;
            end
        end
    end

    if (numel(files_to_zip) > 0)
        zip_file = [ndi.common.PathConstants.TempFolder 'files.zip'];
        zip(zip_file, files_to_zip);
        cur_size = cur_size + doc_file_struct(i).bytes;
        size_gb = cur_size/1e9;
        uploaded_size = uploaded_size + size_gb;
        if verbose
            disp(['Zipping ' int2str(numel(files_to_zip)) ' files.' int2str(size_gb) ' GB in total ' ])
        end
        try
            waitbar(file_count/files_left, h, sprintf('Uploading file %d of %d. Size %.2f GB out of %.2f GB...', file_count, files_left, uploaded_size, total_size));
        catch
        end
        [response, upload_url] = ndi.cloud.api.datasets.get_file_collection_upload_url(dataset_id);
        [response] = ndi.cloud.api.files.put_files(upload_url, zip_file);
        if isfile(zip_file)
            delete(zip_file);
        end
    end
    delete(h);
end
