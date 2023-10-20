classdef Electrode < ndi.database.metadata_app.class.Probe
    properties
        IntrinsicResistance
    end
    
    methods
        function obj = Electrode(varargin)
            obj.checkAndAssign("Name", varargin);
            obj.checkAndAssign("DeviceType", varargin);
            obj.checkAndAssign("Description", varargin);
            obj.checkAndAssign("DigitalIdentifier", varargin);
            obj.checkAndAssign("Manufacturer", varargin);
            obj.checkAndAssign("IntrinsicResistance", varargin);
        end
    end

       
end

