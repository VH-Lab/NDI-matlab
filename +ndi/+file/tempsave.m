function [filePath, cleanupObj] = tempsave(fileUrl, fileName)
% tempsave - Save file from the web to temporary location
%
%   File is automatically deleted when the cleanupObj is deleted or cleared
%   from the workspace

    if nargin < 2
        [~, fileName, fileExtension] = fileparts( char(fileUrl) );
    end

    filePath = websave(fullfile(tempdir, [fileName, fileExtension] ), fileUrl );
    cleanupObj = onCleanup(@(filename) deleteTempFile(filePath));
end

function deleteTempFile(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end
