classdef ProbeData < matlab.mixin.Heterogeneous & handle
%ProbeData A utility class for storing and retrieving information about probes.

    properties
        % PipetteList (1,:) ndi.database.metadata_app.class.Pipette
        % ElectrodeList (1,:) ndi.database.metadata_app.class.Electrode
        % ElectrodeArrayList (1,:) ndi.database.metadata_app.class.ElectrodeArray
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
                case "Electrode Array"
                    probe = ndi.database.metadata_app.class.ElectrodeArray();
                case "Pipette"
                    probe = ndi.database.metadata_app.class.Pipette();
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
            if isempty(obj.ProbeList{index})
                exist = 0;
            else
                exist = 1;
            end
        end

        function added = addPipette(obj, name, deviceType, varargin)
        %addPipette Add the pipette to PipetteList if this name is now
        %already assigned to a type. Return a bool indicating if it is
        %added. 
            if ~isKey(obj.TypeAssigned, name)
                obj.TypeAssigned(name) = true;
                pipette = ndi.database.metadata_app.class.Pipette(name, deviceType, varargin);
                obj.PipetteList(end+1) = {pipette};
                added = 1;
            else
                added = 0;
            end 
        end

        function added = addElectrode(obj, name, deviceType, varargin)
        %addElectrode Add the electrode to ElectrodeList if this name is now
        %already assigned to a type. 
        % Return a bool indicating if it is added. 
            if ~isKey(obj.TypeAssigned, name)
                obj.TypeAssigned(name) = true;
                electrode = ndi.database.metadata_app.class.Electrode(name, deviceType);
                obj.ElectrodeList(end+1) = {electrode};
                added = 1;
            else
                added = 0;
            end 
        end

        function added = addElectrodeArray(obj, name, deviceType, varargin)
        %addElectrodeArray Add the electrodeArray to ElectrodeArrayList if this name is now
        %already assigned to a type. 
        % Return a bool indicating if it is added. 
            if ~isKey(obj.TypeAssigned, name)
                obj.TypeAssigned(name) = true;
                electrodeArray = ndi.database.metadata_app.class.ElectrodeArray(name, deviceType);
                obj.ElectrodeArrayList(end+1) = {electrodeArray};
                added = 1;
            else
                added = 0;
            end 
        end


        function list = getPipetteList(obj)
            list = obj.PipetteList;
        end
       
    end
end
