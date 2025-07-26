function folderPath = projectdir()
% projectdir - Get project (repository) root directory for the ndi_matlab package
    folderPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
