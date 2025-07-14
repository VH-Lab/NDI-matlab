function directoryPath = toolboxdir()

    thisFilePath = mfilename("fullpath");
    splitPath = strsplit(thisFilePath, filesep);
    directoryPath = strjoin(splitPath(1:end-3), filesep);
end
