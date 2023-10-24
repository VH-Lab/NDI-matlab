classdef Electrode < ndi.database.metadata_app.class.Probe
    properties
        IntrinsicResistance
    end
    
    methods
        function obj = Electrode(varargin)
            obj.ClassType = "Electrode";
        end
    end

       
end

