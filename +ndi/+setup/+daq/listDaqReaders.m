function [names, absPaths, functionNames] = listDaqReaders()

    % Collect paths of all root folders containing daq readers in a cell array
    rootPath = {};
    rootPath{1} = ndi.util.getPackageDir('ndi.daq.reader');
    rootPath{2} = ndi.util.getPackageDir('ndi.setup.daq.reader');

    % Find all m-files in these root folders.
    fileExtension = '.m';
    fileList = recursiveDir(rootPath, 'Type', 'file', 'FileType', fileExtension);
    
    absPaths = abspath(fileList);
    names = {fileList.name};
    names = strrep(names, fileExtension, '');

    if nargout < 2
        clear absPath
    end

    if nargout == 3
        functionNames = utility.path.abspath2funcname(absPaths);
    end

    % Todo: Return a struct, with following fields:
    % full path
    % package/full function name
    % category, i.e mfdaq, tplsm, ephys etc...
end