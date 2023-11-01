classdef Pipette < ndi.database.metadata_app.class.Probe
    properties
        InternalDiameter
        InternalDiameterUnit
    end
    
    methods
       function obj = Pipette(varargin)
            obj.ClassType = "Pipette";
            obj.InternalDiameterUnit = 'not selected';
            obj.InternalDiameter = '';
       end

       function selected = InternalDiameterUnitSelected(obj)
            if strcmp(obj.InternalDiameterUnit, 'not selected')
                selected = 0;
            else
                selected = 1;
            end
       end
    end
end
