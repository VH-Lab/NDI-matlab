classdef ProbeData < handle
    properties
        pipetteList (1,:) ndi.database.metadata_app.class.Pipette
        ElectrodeList (1,:) ndi.database.metadata_app.class.Electrode
        ElectrodeArrayList (1,:) ndi.database.metadata_app.class.ElectrodeArray
        isIdentified %A Map storing all the probe names that have identified. 
    end
    
    methods
        function obj = ProbeData()
            obj.isIdentified = containers.Map;
        end

        function addPipette(obj, name, deviceType, varargin)
            
            pipette = ndi.database.metadata_app.class.Pipette(name, deviceType);
            obj.pipetteList(end + 1) = pipette;
        end
        function list = getPipetteList(obj)
            list = obj.pipetteList;
        end
       
    end
end
