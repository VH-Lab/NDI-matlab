classdef Pipette < ndi.database.metadata_app.class.Probe
    properties
        ExternalDiameter
        InternalDiameter
        Material
    end
    
    methods
       function obj = Pipette(varargin)
            obj.ClassType = "Pipette";
       end
    end
end
