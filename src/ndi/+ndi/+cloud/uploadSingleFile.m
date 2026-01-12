function [b, errormsg] = uploadSingleFile(cloudDatasetID, cloudFileUID, filePath, options)
% UPLOADSINGLEFILE: Upload a single file to the NDI cloud service
%
%   [B, ERRORMSG] = ndi.cloud.uploadSingleFile(CLOUDDATASETID, CLOUDFILEUID, FILEPATH, ...)
%
%   Uploads a single file to the NDI cloud service.
%
%   Inputs:
%   cloudDatasetID - The ID of the dataset in the cloud.
%   cloudFileUID - The unique ID to be assigned to the file.
%   filePath - The local path of the file to be uploaded.
%
%   Name-Value Pairs:
%   'useBulkUpload' (logical) - If true, the file will be zipped and uploaded
%                               using the bulk upload mechanism. Defaults to false.
%
%   Outputs:
%   B - true if the upload was successful, false otherwise.
%   ERRORMSG - An error message if the upload failed, empty otherwise.
%
    arguments
        cloudDatasetID (1,1) string
        cloudFileUID (1,1) string
        filePath (1,1) string {mustBeFile}
        options.useBulkUpload (1,1) logical = false
        options.useCurl (1,1) logical = true
    end

    errormsg = '';

    if options.useBulkUpload
        uniqueString = string(did.ido.unique_id());
        zipFileName = cloudDatasetID + "." + uniqueString + ".zip";
        zip_file = fullfile(tempdir, zipFileName);
        try
            zip(zip_file, filePath);

            [b_url, url_or_error] = ndi.cloud.api.files.getFileCollectionUploadURL(cloudDatasetID);
            if ~b_url
                error(['Could not get file collection upload URL: ' url_or_error.message]);
            end

            [b_put, put_or_error] = ndi.cloud.api.files.putFiles(url_or_error, zip_file);
            if ~b_put
                error(['Could not upload zip file: ' put_or_error.message]);
            end

        catch e
            b = false;
            errormsg = e.message;
            if isfile(zip_file), delete(zip_file); end
            return;
        end
        if isfile(zip_file), delete(zip_file); end
    else
        % Get the pre-signed URL for single file upload
        [b_url, url_or_error] = ndi.cloud.api.files.getFileUploadURL(cloudDatasetID, cloudFileUID);

        if ~b_url
            b = false;
            errormsg = ['Could not get file upload URL: ' url_or_error.message];
            return;
        end

        % Upload the file
        [b_put, put_or_error] = ndi.cloud.api.files.putFiles(url_or_error, filePath, 'useCurl', options.useCurl);

        if ~b_put
            b = false;
            errormsg = ['Could not upload file: ' put_or_error.message];
            return;
        end
    end

    b = true;
end
