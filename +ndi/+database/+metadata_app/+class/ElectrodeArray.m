classdef ElectrodeArray < ndi.database.metadata_app.class.Probe
    properties
        Description
        IntrinsicResistance
    end
    
    methods
        function obj = ElectrodeArray(name, deviceType, digitalIdentifier, manufacturer, description, intrinsicResistance)
            obj@ndi.database.metadata_app.class.Probe(name, deviceType);
            if nargin > 0
                obj.Description = description;
                obj.IntrinsicResistance = intrinsicResistance;
            end
        end

       
    end
end
