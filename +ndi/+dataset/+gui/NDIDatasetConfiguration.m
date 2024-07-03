classdef NDIDatasetConfiguration < handle
% NDIDatasetConfiguration - Class with properties and methods for
% configuring an NDI dataset.
%
%   Configuring an NDI Dataset mainly consist of the following actions:
%       1) Specify a dataset root folder
%       2) Specify how dataset is organized in subfolders
%       3) Extracting identifiers / tokens from foldernames
%       4) Configuring DAQ systems for the dataset.
%
%   This class can be used from the command window, but there is also the
%   app "ndi.dataset.gui.NDIDatasetWizardApp" which provides an interactive
%   manner of configuring an NDI dataset.

    properties (SetAccess = private, SetObservable)
        DatasetRootDirectory (1,1) string = missing
        DatasetInformation ndi.dataset.gui.models.DatasetInfo
        FolderModel ndi.dataset.gui.models.FolderOrganizationModel
        MetadataExtractor
        %DaqSystems (1,:) ndi.setup.DaqSystemConfiguration
        DaqSystemsCollection ndi.dataset.gui.models.DaqSystemCollection
    end

    methods % Constructor
        function obj = NDIDatasetConfiguration(datasetFolder)
            arguments
                datasetFolder (1,1) string = missing
            end
            
            obj.DatasetRootDirectory = datasetFolder;
        end
    end

    methods % User methods
        function save(obj, filePath)
            obj.saveDatasetConfiguration()
        end

        function tf = isClean(obj)
            tf = false(1,3);

            filePath = obj.getDatasetMetadataFile();
            tf(1) = obj.DatasetInformation.isClean(filePath);
            
            filePath = obj.getFolderOrganizationConfigurationFile();
            tf(2) = obj.FolderModel.isClean(filePath);

            filePath = obj.getDaqSystemConfigurationFile();
            tf(3) = obj.DaqSystemsCollection.isClean(filePath);

            tf = all(tf);
        end

        function uigetdir(obj)
            rootDirectory = uigetdir();
            if ~rootDirectory == 0
                obj.DatasetRootDirectory = rootDirectory;
            end
        end
    end

    methods % Property set methods
        function set.DatasetRootDirectory(obj, newValue)
            obj.DatasetRootDirectory = newValue;
            obj.postSetDatasetRootDirectorySet()
        end
    end

    methods (Access = private) % Property set callbacks
        function postSetDatasetRootDirectorySet(obj)
            if ~ismissing(obj.DatasetRootDirectory)
                obj.loadDatasetConfiguration()
            end
            obj.FolderModel.RootDirectory = obj.DatasetRootDirectory;
        end
    end

    methods (Access = private) % Internal
        function initializeModels(obj)
            obj.FolderModel = ndi.dataset.gui.models.FolderOrganizationModel();
            %obj.FolderModel.addSubFolderLevel()
        end

        function loadDatasetConfiguration(obj)
            
            % Load dataset information
            filePath = obj.getDatasetMetadataFile('nocreate');
            if isfile(filePath)
                S = load(filePath);
                obj.DatasetInformation = S.DatasetInformation;
            else
                obj.DatasetInformation = ndi.dataset.gui.models.DatasetInfo();
            end

            % Load folder organization
            filePath = obj.getFolderOrganizationConfigurationFile('nocreate');
            if isfile(filePath)
                obj.FolderModel = ndi.dataset.gui.models.FolderOrganizationModel.fromJson(filePath);
            else
                obj.FolderModel = ndi.dataset.gui.models.FolderOrganizationModel();
                obj.FolderModel.addSubFolderLevel();
            end

            % Load DAQ systems
            filePath = obj.getDaqSystemConfigurationFile('nocreate');
            if isfile(filePath)
                daqSystemModel = ndi.dataset.gui.models.DaqSystemCollection.fromJson(filePath);
            else
                daqSystemModel = ndi.dataset.gui.models.DaqSystemCollection();
            end
            obj.DaqSystemsCollection = daqSystemModel;
        end

        function saveDatasetConfiguration(obj)
            filePath = obj.getFolderOrganizationConfigurationFile();
            obj.FolderModel.toJson(filePath)

            filePath = obj.getDaqSystemConfigurationFile();
            obj.DaqSystemsCollection.toJson(filePath)

            % Load dataset information
            filePath = obj.getDatasetMetadataFile();
            S = struct('DatasetInformation', obj.DatasetInformation);
            save(filePath, "-struct", "S")
        end

        function pathName = getDatasetSubfolder(obj, subfolder, mode)
            arguments
                obj (1,1) ndi.dataset.gui.NDIDatasetConfiguration
                subfolder (1,1) string
                mode (1,1) string {mustBeMember(mode, ["create", "nocreate"])} = "create"
            end
            pathName = fullfile(obj.DatasetRootDirectory, '.ndi', subfolder);
            if mode == "create"
                if ~isfolder(pathName)
                    mkdir(pathName)
                end
            else
                % pass
            end
        end

        function pathName = getDatasetConfigurationFolder(obj, mode)
            pathName = obj.getDatasetSubfolder('configuration', mode);
        end

        function pathName = getFolderOrganizationConfigurationFile(obj, mode)
            arguments
                obj (1,1) ndi.dataset.gui.NDIDatasetConfiguration
                mode (1,1) string {mustBeMember(mode, ["create", "nocreate"])} = "create"
            end
            configFolder = obj.getDatasetConfigurationFolder(mode);
            pathName = fullfile(configFolder, 'folder_organization_spec.json');
        end

        function pathName = getDaqSystemConfigurationFile(obj, mode)
            arguments
                obj (1,1) ndi.dataset.gui.NDIDatasetConfiguration
                mode (1,1) string {mustBeMember(mode, ["create", "nocreate"])} = "create"
            end
            configFolder = obj.getDatasetConfigurationFolder(mode);
            pathName = fullfile(configFolder, 'daq_system_spec.json');
        end

        function pathName = getDatasetMetadataFile(obj, mode)
            arguments
                obj (1,1) ndi.dataset.gui.NDIDatasetConfiguration
                mode (1,1) string {mustBeMember(mode, ["create", "nocreate"])} = "create"
            end
            configFolder = obj.getDatasetSubfolder('metadata', mode);
            pathName = fullfile(configFolder, 'DatasetMetadata.mat');
        end
    end
end