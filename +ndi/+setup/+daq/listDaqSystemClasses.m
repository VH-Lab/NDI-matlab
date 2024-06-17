function [names, absPaths] = listDaqSystemClasses()
    
    rootPath = fileparts( which('ndi.version') );
    rootPath = fullfile(rootPath, '+daq', '+system');

    fileExtension = '.m';
    fileList = recursiveDir(rootPath, 'Type', 'file', 'FileType', fileExtension);
    
    absPaths = abspath(fileList);
    names = {fileList.name};
    names = strrep(names, fileExtension, '');
    
    if nargout < 2
        clear absPath
    end
end