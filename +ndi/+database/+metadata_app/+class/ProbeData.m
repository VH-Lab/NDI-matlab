classdef ProbeData < matlab.mixin.Heterogeneous & handle
%ProbeData A utility class for storing and retrieving information about probes.

    properties
        TypeAssigned %A Map storing all the probes that have selected a type. 
        ProbeList
    end
    
    methods
        function obj = ProbeData()
            obj.TypeAssigned = containers.Map;
            obj.ProbeList = {};
        end

        function createNewProbe(obj, index, probeType)
            switch probeType
                case "Electrode"
                    probe = ndi.database.metadata_app.class.Electrode();
                % case "Electrode Array"
                %     probe = ndi.database.metadata_app.class.ElectrodeArray();
                case "Pipette"
                    probe = ndi.database.metadata_app.class.Pipette();
                % case "Miscellaneous"
                %     probe = ndi.database.metadata_app.class.MiscellaneousProbe();
            end
            obj.addnewProbe(index, probe);
        end

        function addnewProbe(obj, index, probe)
            if numel(obj.ProbeList) + 1 < index
                obj.ProbeList(end+1:index - 1) = {''};                
            end
            obj.ProbeList(index) = {probe};
        end

        function exist = probeExist(obj, index)
            if numel(obj.ProbeList) < index || isempty(obj.ProbeList{index})
                exist = 0;
            else
                exist = 1;
            end
        end

        function t = formtaTable(obj)
            t = [];
            for i = 1:numel(obj.ProbeList)
                if ~isempty(obj.ProbeList{i})
                    t = [t; obj.ProbeList{i}.toTableStruct()];
                end
            end
        end

        function list = getPipetteList(obj)
            list = obj.PipetteList;
        end
       
    end
end
