function [zipFilePath, idManifest] = zip_documents_for_upload(documentList, options)
    % ZIP_DOCUMENTS_FOR_UPLOAD - Serializes and zips a list of documents for upload.
    %
    % This function takes a cell array of ndi.document objects, converts them into a 
    % single JSON string, saves this string to a temporary file, and then compresses 
    % this file into a zip archive. It returns the path to the zip archive and a 
    % manifest of the document IDs included.
    %
    % Arguments:
    %   documentList (1,:) cell - A cell array of ndi.document objects to be included
    %       in the zip file.
    %   options.TargetFolder (1,1) string {mustBeFolder} - An optional name-value
    %       argument specifying the folder where the zip file will be created. 
    %       Defaults to the system's temporary folder as defined by 
    %       ndi.common.PathConstants.TempFolder.
    %
    % Returns:
    %   zipFilePath (string) - The full path to the generated .zip file.
    %   idManifest (cell array) - A cell array of strings containing the unique
    %       identifiers of the documents included in the archive.
    %
    % Important:
    %   The user is responsible for deleting the file at zipFilePath once it is no
    %   longer needed to prevent clutter in the target folder.
    %
    % Example:
    %   % Assuming doc1 and doc2 are valid ndi.document objects
    %   myDocs = {doc1, doc2};
    %   [zipPath, idList] = zip_documents_for_upload(myDocs);
    %   % ... code to upload the file at zipPath ...
    %   delete(zipPath); % Clean up the created zip file
    %

    arguments
        documentList (1,:) cell
        options.TargetFolder (1,1) string {mustBeFolder} = ndi.common.PathConstants.TempFolder
    end

    % Convert documents to a JSON string
    jsonStr = did.datastructures.jsonencodenan( documentList );
    idManifest = cellfun(@(x) x.id(),documentList,'UniformOutput',false);
    
    % Open the file for writing
    jsonFilename = ndi.file.temp_name();
    fid = fopen(jsonFilename, 'wt');
    % Write the JSON string to the file
    fprintf(fid, '%s', jsonStr);
    fclose(fid);
        
    % Zip the JSON file into a zip archive
    % use randomized name in case multiple threads
    id = ndi.ido;
    zipFName = id.identifier;
    zipFilePath = fullfile(options.TargetFolder, [zipFName '.zip']);
    zip(zipFilePath, jsonFilename);

    delete(jsonFilename);

end
