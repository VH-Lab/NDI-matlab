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
%   'checksum' (logical)      - If true (default), compute the file's CRC-32
%                               (ndi.fun.file.crc32) and send it with the
%                               single-file upload URL request, so S3 rejects a
%                               corrupted upload and NDI Cloud records the
%                               file's crc32. Ignored for bulk uploads, whose
%                               zip entries carry their own CRC-32.
%   'waitForUpload' (logical) - If true (default), return only once NDI Cloud
%                               has recorded the upload (ndi.cloud.api.files.
%                               waitForFileUpload; for bulk uploads, the zip
%                               extraction job). A PUT returning 200 only
%                               means S3 has the object; the server records
%                               it shortly after. Set false when uploading
%                               many files and wait for them all at once.
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
        options.checksum (1,1) logical = true
        options.waitForUpload (1,1) logical = true
    end

    errormsg = '';

    if options.useBulkUpload
        uniqueString = string(did.ido.unique_id());
        zipFileName = cloudDatasetID + "." + uniqueString + ".zip";
        zip_file = fullfile(tempdir, zipFileName);
        try
            zip(zip_file, filePath);

            [b_url, info_or_error] = ndi.cloud.api.files.getFileCollectionUploadURL(cloudDatasetID);
            if ~b_url
                error(['Could not get file collection upload URL: ' info_or_error.message]);
            end

            [b_put, put_or_error] = ndi.cloud.api.files.putFiles(info_or_error.url, zip_file, ...
                'useCurl', options.useCurl, ...
                'jobId', info_or_error.jobId, ...
                'waitForCompletion', options.waitForUpload);
            if ~b_put
                if isstruct(put_or_error) && isfield(put_or_error, 'message')
                    detail = put_or_error.message;
                elseif isstruct(put_or_error) && isfield(put_or_error, 'state')
                    % waitForCompletion's final bulk-upload status
                    detail = ['bulk upload job ended in state ' char(string(put_or_error.state))];
                elseif ischar(put_or_error) || isstring(put_or_error)
                    detail = char(put_or_error);
                else
                    detail = jsonencode(put_or_error);
                end
                error(['Could not upload zip file: ' detail]);
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
        checksumCRC32 = "";
        if options.checksum
            checksumCRC32 = string(ndi.fun.file.crc32(filePath));
        end
        [b_url, url_or_error] = ndi.cloud.api.files.getFileUploadURL(cloudDatasetID, cloudFileUID, ...
            'checksumCRC32', checksumCRC32);

        if ~b_url
            b = false;
            errormsg = ['Could not get file upload URL: ' url_or_error.message];
            return;
        end

        % Upload the file
        [b_put, put_or_error] = ndi.cloud.api.files.putFiles(url_or_error, filePath, 'useCurl', options.useCurl, ...
            'checksumCRC32', checksumCRC32);

        if ~b_put
            b = false;
            errormsg = ['Could not upload file: ' put_or_error.message];
            return;
        end

        if options.waitForUpload
            [b_wait, wait_answer] = ndi.cloud.api.files.waitForFileUpload(cloudDatasetID, cloudFileUID);
            if ~b_wait
                b = false;
                errormsg = sprintf(['File was sent but NDI Cloud did not record the upload ' ...
                    'within %.0f s (state: %s).'], wait_answer.elapsed, wait_answer.state);
                return;
            end
        end
    end

    b = true;
end
