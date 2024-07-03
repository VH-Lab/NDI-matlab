function logoFilePath = getLogoPath(name, mode)
%getLogoPath - Get filepath for a logo resource
    arguments
        name (1,1) string {mustBeMember(name, ["ndi_cloud"])} = "ndi_cloud"
        mode (1,1) string {mustBeMember(mode, ["light", "dark"])} = "light"
    end
    % Todo: use ndi.util.toolboxdir
    rootPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    logoFolderPath = fullfile(rootPath, 'resources', 'images');
    fileName = sprintf('%s_logo_%s.png', name, mode);
    logoFilePath = fullfile(logoFolderPath, fileName);
end