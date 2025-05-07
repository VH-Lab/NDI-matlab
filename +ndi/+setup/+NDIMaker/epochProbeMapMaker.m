% Folder: +ndi/+setup/+NDIMaker/
classdef epochProbeMapMaker < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here

    properties (Access = public)
        path (1,:) char         % Base directory path where session folders are located or will be created.
        variableTable table     % Input table containing session definition information. Must contain 'SubjectString' and 'SessionPath' variables.
        daqName                 % Name of the lab configuration directory containing the DAQ system definition files.
        probeDictionary
    end

    methods
        function obj = epochProbeMapMaker(path,variableTable,probeTable,options)
            %UNTITLED2 Construct an instance of this class
            %   Detailed explanation goes here
            % Create probe maps
            % Get full file paths for each epoch
            arguments
                path
                variableTable
                probeTable
                options.ProbePostfix
            end
            
            epochInd = ~strcmp(variableTable.SubjectString,'');
            epochstreams = fullfile(path,variableTable.Properties.RowNames(epochInd));
            subjectString = variableTable.SubjectString(epochInd);
            recordingDate = datetime(variableTable.RecordingDate(epochInd),'InputFormat','MMM dd yyyy');
            sliceLabel = variableTable.sliceLabel(epochInd);
            sliceLabel(strcmp(sliceLabel,{''})) = {'a'};

            % How do we imagine this working for multiple subjects per epoch?
            % Might want subjectString to have {'sub1','sub2','subN'} per
            % row in variableTable
            deviceNames = ndi.setup.daq.system.listDaqSystemNames(daqName);
            for d = 1:numel(deviceNames)
                daqSystemConfig = ndi.setup.DaqSystemConfiguration.fromLabDevice(labName, deviceNames{d});
                reader = ndr.reader.(daqSystemConfig.DaqReaderFileParameters);
            end
            for e = 1:numel(epochstreams)
                channels = reader.getchannelsepoch(epochstreams,e);
                channels(strcmp({channels.type},'time')) = [];
                recordDateStr = char(recordingDate(e),'yyMMdd');
                for c = 1:numel(channels)
                    
                    probeType = char(probeDictionary(channels(c).type));
                    probeName = strjoin({probeType,recordDateStr,sliceLabel{e}},'_');
                    probemap(c) = ndi.epoch.epochprobemap_daqsystem(probeName,...
                        1,probeType,[daqName,':',channels(c).name],subjectString{e});
                end
                [pathname,filename] = fileparts(epochstreams{e});
                probeFilename = fullfile(pathname,strcat(filename,'.epochprobemap.txt'));
                probemap.savetofile(probeFilename);
            end
        end
    end
end