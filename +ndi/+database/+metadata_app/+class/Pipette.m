classdef Pipette < ndi.database.metadata_app.class.Probe
    properties
        ExternalDiameter
        ExternalDiameterUnit
        InternalDiameter
        InternalDiameterUnit
        Material
    end
    
    methods
       function obj = Pipette(varargin)
            obj.ClassType = "Pipette";
            obj.ExternalDiameterUnit = 'not selected';
            obj.ExternalDiameter = '';
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

       function selected = ExternalDiameterUnitSelected(obj)
            if strcmp(obj.ExternalDiameterUnit, 'not selected')
                selected = 0;
            else
                selected = 1;
            end
        end
    end
end
