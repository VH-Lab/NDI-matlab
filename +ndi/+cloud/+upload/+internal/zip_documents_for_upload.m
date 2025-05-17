function [zipFilePath, fileCleanupObj] = zip_documents_for_upload(documentList, options)

    arguments
        documentList (1,:) cell
        options.TargetFolder (1,1) string {mustBeFolder} = pwd
    end

    % Convert documents to a JSON string
    jsonStr = did.datastructures.jsonencodenan( documentList );
    
    % Open the file for writing
    jsonFilename = fullfile(tempdir, 'temp_ndi_documents.json');
    fid = fopen(jsonFilename, 'wt');
    jsonFileCloseCleanup = onCleanup(@() fclose(fid));
    jsonFileDeleteCleanup = onCleanup(@() delete(jsonFilename));

    % Write the JSON string to the file
    fprintf(fid, '%s', jsonStr);
        
    clear jsonFileCloseCleanup % Closes the file

    % Zip the JSON file into a zip archive
    zipFilePath = fullfile(options.TargetFolder, 'temp_ndi_document_archive.zip');
    zip(zipFilePath, jsonFilename);

    clear jsonFileDeleteCleanup % Deletes the file

    if nargout == 2
        fileCleanupObj = onCleanup(@() delete(zipFilePath));
    end
end
