classdef Pipette < ndi.database.metadata_app.class.Probe
    properties
        ExternalDiameter
        InternalDiameter
        Material
    end
    
    methods
        function obj = Pipette(varargin)
            obj.checkAndAssign("Name", varargin);
            obj.checkAndAssign("deviceType", varargin);
            obj.checkAndAssign("Description", varargin);
            obj.checkAndAssign("DigitalIdentifier", varargin);
            obj.checkAndAssign("Manufacturer", varargin);
            obj.checkAndAssign("ExternalDiameter", varargin);
            obj.checkAndAssign("InternalDiameter", varargin);
            obj.checkAndAssign("Material", varargin);
        end
       
    end
end
