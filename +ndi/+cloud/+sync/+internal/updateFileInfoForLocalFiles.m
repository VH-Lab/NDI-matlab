function document = updateFileInfoForLocalFiles(document, fileDirectory)
% updateFileInfoForLocalFiles - Update file info of document for local files
%
% Syntax:
%   document = ndi.cloud.sync.internal.updateFileInfoForLocalFiles(document, fileDirectory)
%       updates the file info of the document to point to a file in the
%       provided (local) file directory
%
% Input Arguments: 
%   document - The document object that contains file info to be updated
%   fileDirectory - The directory where local files are stored
%
% Output Arguments: 
%   document - The updated document object with new file info
%
% See also:
%   ndi.cloud.sync.internal.updateFileInfoForRemoteFiles

    if document.has_files()
        originalFileInfo = document.document_properties.files.file_info;
        document = document.reset_file_info();
    
        for i = 1:numel(originalFileInfo)
            file_uid = originalFileInfo(i).locations(1).uid;
            file_location = fullfile(fileDirectory, file_uid);
    
            filename = originalFileInfo(i).name; % name for ingestion
            if isfile(file_location)
                document = document.add_file(filename, file_location);
            else
                warning('Local file does not exist for document "%s"', ...
                    document.document_properties.base.id)
            end
        end
    end

    

end

