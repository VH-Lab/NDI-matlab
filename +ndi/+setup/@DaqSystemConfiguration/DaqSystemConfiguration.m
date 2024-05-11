classdef DaqSystemConfiguration
%DaqSystemConfiguration Parameters for configuring a DAQ System.

    properties
        Name (1,1) string = missing
        DaqSystemClass (1,1) string = "ndi.daq.system.mfdaq"
        DaqReaderClass (1,1) string = "ndi.daq.reader.mfdaq"
        MetadataReaderClass (1,:) string = string.empty
        EpochProbeMapClass (1,1) string = "ndi.epoch.epochprobemap_daqsystem"
        FileParameters (1,:) string = string.empty
        DaqReaderFileParameters (1,:) string = string.empty
        MetadataReaderFileParameters (1,:) string = string.empty
        EpochProbeMapFileParameters (1,:) string = string.empty
        HasEpochDirectories (1,1) logical = false
    end

    methods
        function obj = DaqSystemConfiguration(name, propertyValues)
            arguments
                name
                propertyValues.?ndi.setup.DaqSystemConfiguration
            end

            obj.Name = name;

            for propName = string( fieldnames( propertyValues)' )
                obj.(propName) = propertyValues.(propName);
            end
        end
    end

    methods
        function ndiSession = create(obj, ndiSession)
        % create - Create and add DAQ System to session

            fileNavigator = obj.createFileNavigator(ndiSession);
            daqReader = obj.createDaqReader();
            metadataReader = obj.createMetadataReader();

            daqSystem = feval(obj.DaqSystemClass, ...
                obj.Name, ...
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
                obj.FileParameters, ...
                obj.EpochProbeMapClass, ...
                obj.EpochProbeMapFileParameters );
        end

        function daqReader = createDaqReader(obj)
            if isempty(obj.DaqReaderFileParameters)
                daqReader = feval(obj.DaqReaderClass);
            else
                daqReader = feval(obj.DaqReaderClass, obj.DaqReaderFileParameters);
            end
        end

        function metadataReader = createMetadataReader(obj)
            if isempty(obj.MetadataReaderClass)
                metadataReader = {};
            else
                if numel(obj.MetadataReaderFileParameters) > 1
                    if numel(obj.MetadataReaderClass) == 1
                        metadataReader = arrayfun(@(fp) feval(obj.MetadataReaderClass, fp), ...
                            obj.MetadataReaderFileParameters, ...
                            'UniformOutput', false);
                    else
                        assert( numel(obj.MetadataReaderFileParameters) == numel(obj.MetadataReaderClass), ...
                           'Expected one metadata reader per metadata file parameter')
                        metadataReader = arrayfun(@(i) feval(obj.MetadataReaderClass(i), obj.MetadataReaderFileParameters(i)), ...
                            1:numel(obj.MetadataReaderFileParameters), ...
                            'UniformOutput', false);
                    end
                else
                    metadataReader = { feval(obj.MetadataReaderClass, ...
                        obj.MetadataReaderFileParameters) };
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
            ndi.globals; 
            importDir = fullfile(ndi_globals.path.commonpath, 'daq_systems', labName);
            configFilePath = fullfile(importDir, [deviceName, '.json']);
            daqSystemConfiguration = ndi.setup.DaqSystemConfiguration.fromConfigFile(configFilePath);
        end
    end
end

function ME = DaqSystemConfigFileNotFound(fileName)
    ME = MException('NDI:Setup:DaqSystemConfigurationFileNotFound', ...
        'The given file (%s) does not exist', fileName);
end