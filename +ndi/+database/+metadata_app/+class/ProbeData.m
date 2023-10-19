classdef ProbeData < handle
    properties
        pipetteList (1,:) ndi.database.metadata_app.class.Pipette
    end
    
    methods
        % function obj = ProbeList()
        % 
        % end

        function addPipette(obj, name, deviceType)
            pipette = ndi.database.metadata_app.class.Pipette(name, deviceType);
            obj.pipetteList(end + 1) = pipette;
        end
        function list = getPipetteList(obj)
            list = obj.pipetteList;
        end
       
    end
end
