classdef DaqSystemConfiguration
    %DaqSystemConfiguration Parameters for configuring a DAQ System.

    properties
        % Name - A name for the DAQ system device
        Name (1,1) string = ""

        % DaqSystemClass - Full class name for the class to use for
        % creating an NDI DAQ system object
        DaqSystemClass (1,1) string = "ndi.daq.system.mfdaq"

        % DaqReaderClass - Full class name for the class to use for
        % creating an NDI DAQ reader object
        DaqReaderClass (1,1) string = "ndi.daq.reader.mfdaq"

        % MetadataReaderClass - Full class name for the class to use for
        % creating an NDI metadata reader object
        MetadataReaderClass (1,:) string = string.empty

        % EpochProbeMapClass - Full name of class that specifies the epoch
        % probe map.
        EpochProbeMapClass (1,1) string = "ndi.epoch.epochprobemap_daqsystem"

        % FileParameters - A list of file patterns of files that are
        % recorded / stored for each epoch of this DAQ System device.
        FileParameters (1,:) string = string.empty

        % DaqReaderFileParameters - A list of file parameters that are
        % specific to the DAQ Reader (subset of FileParameters).
        DaqReaderFileParameters (1,:) string = string.empty

        % MetadataReaderFileParameters - A list of file parameters that are
        % specific to the Metadata Reader (subset of FileParameters).
        MetadataReaderFileParameters (1,:) string = string.empty

        % EpochProbeMapFileParameters - A list of file parameters that are
        % specific to Epoch Probe Map (subset of FileParameters).
        EpochProbeMapFileParameters (1,:) string = string.empty

        % HasEpochDirectories - Whether epochs are organized in
        % subdirectories.
        HasEpochDirectories (1,1) logical = false
    end

    methods
        function obj = DaqSystemConfiguration(name, propertyValues)
            arguments
                name (1,1) string = ""
                propertyValues.?ndi.setup.DaqSystemConfiguration
            end

            obj.Name = name;

            for propName = string( fieldnames( propertyValues)' )
                obj.(propName) = propertyValues.(propName);
            end
        end
    end

    methods
        function ndiSession = addToSession(obj, ndiSession)
            % addToSession - Create and add DAQ System to session

            fileNavigator = obj.createFileNavigator(ndiSession);
            daqReader = obj.createDaqReader();
            metadataReader = obj.createMetadataReader();

            daqSystem = feval(obj.DaqSystemClass, ...
                char(obj.Name), ...
                fileNavigator, ...
                daqReader, ...
                metadataReader );

            ndiSession = ndiSession.daqsystem_add(daqSystem);
        end

        function export(obj, configFileName)
            % export - Export a DAQ System configuration to json
            propertyNames = properties(obj);

            S = struct;
            for propName = string(propertyNames')
                S.(propName) = obj.(propName);
            end

            jsonStr = jsonencode(S, 'PrettyPrint', true);

            fid = fopen(configFileName, 'w');
            fwrite(fid, jsonStr);
            fclose(fid);
        end
    end

    methods (Access = private)
        function fileNavigator = createFileNavigator(obj, ndiSession)
            % createFileNavigator - Create an instance of a file navigator
            if obj.HasEpochDirectories
                navigatorClass = @ndi.file.navigator.epochdir;
            else
                navigatorClass = @ndi.file.navigator;
            end

            fileNavigator = navigatorClass(...
                ndiSession, ...
                cellstr(obj.FileParameters), ...
                char(obj.EpochProbeMapClass), ...
                cellstr(obj.EpochProbeMapFileParameters) );
        end

        function daqReader = createDaqReader(obj)
            if isempty(obj.DaqReaderFileParameters)
                daqReader = feval(obj.DaqReaderClass);
            else
                daqReader = feval(obj.DaqReaderClass, char(obj.DaqReaderFileParameters));
            end
        end

        function metadataReader = createMetadataReader(obj)
            if isempty(obj.MetadataReaderClass)
                metadataReader = {};
            else
                if numel(obj.MetadataReaderFileParameters) > 1
                    if numel(obj.MetadataReaderClass) == 1
                        metadataReader = arrayfun(@(fp) feval(obj.MetadataReaderClass, char(fp)), ...
                            obj.MetadataReaderFileParameters, ...
                            'UniformOutput', false);
                    else
                        assert( numel(obj.MetadataReaderFileParameters) == numel(obj.MetadataReaderClass), ...
                            'Expected one metadata reader per metadata file parameter')
                        metadataReader = arrayfun(@(i) feval(obj.MetadataReaderClass(i), char(obj.MetadataReaderFileParameters(i))), ...
                            1:numel(obj.MetadataReaderFileParameters), ...
                            'UniformOutput', false);
                    end
                else
                    metadataReader = { feval(obj.MetadataReaderClass, ...
                        char(obj.MetadataReaderFileParameters) ) };
                end
            end
        end
    end

    methods (Static)
        function daqSystemConfiguration = fromConfigFile(configFilePath)
            % fromConfigFile - Create a DAQ system configuration object from file

            if isfile(configFilePath)
                [~, name] = fileparts(configFilePath);
                S = jsondecode( fileread(configFilePath) );
                S = rmfield(S, 'Name');
                nvPairs = namedargs2cell(S);
                daqSystemConfiguration = ...
                    ndi.setup.DaqSystemConfiguration(name, nvPairs{:});
            else
                throw( DaqSystemConfigFileNotFound(configFilePath) )
            end
        end

        function daqSystemConfiguration = fromLabDevice(labName, deviceName)
            importDir = fullfile(ndi.common.PathConstants.CommonFolder, 'daq_systems', labName);
            configFilePath = fullfile(importDir, [deviceName, '.json']);
            daqSystemConfiguration = ndi.setup.DaqSystemConfiguration.fromConfigFile(configFilePath);
        end

        function daqSystemConfiguration = fromDeviceName(deviceName)
            ndi.globals; 
            importDir = fullfile(ndi_globals.path.commonpath, 'daq_systems');
            configFilePath = recursiveDir(importDir, 'FileType', '.json', 'Expression', deviceName, 'OutputType', 'FilePath');
            assert(iscell(configFilePath) && numel(configFilePath)==1)
            daqSystemConfiguration = ndi.setup.DaqSystemConfiguration.fromConfigFile(configFilePath{1});
        end
    end
end

function ME = DaqSystemConfigFileNotFound(fileName)
    ME = MException('NDI:Setup:DaqSystemConfigurationFileNotFound', ...
        'The given file (%s) does not exist', fileName);
end
