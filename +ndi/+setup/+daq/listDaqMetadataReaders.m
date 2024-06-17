function [names, absPaths] = listDaqMetadataReaders()
    
    % Collect paths of all root folders containing daq mdreaders in a cell array
    rootPath = {};
    rootPath{1} = ndi.util.getPackageDir('ndi.daq.metadatareader');
    rootPath{2} = ndi.util.getPackageDir('ndi.setup.daq.metadatareader');
    
    % Find all m-files in these root folders.
    fileExtension = '.m';
    fileList = recursiveDir(rootPath, 'Type', 'file', 'FileType', fileExtension);
    
    % Add generic metadata reader:
    pathStr = which('ndi.daq.metadatareader');
    fileList = [dir(pathStr); fileList];

    names = {fileList.name};
    names = strrep(names, fileExtension, '');
    
    if nargout >= 2
        absPaths = ndi.util.dir2abspath(fileList);
    end
end
