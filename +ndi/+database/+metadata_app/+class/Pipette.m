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

        %check if intrinsic diameter is filled and if unit is selected
        %return false if value is filled but unit is not selected
        function filled = intrinsicDiameterCheck(obj)
            if ~isempty(obj.InternalDiameter) && ~obj.InternalDiameterUnitSelected()
                filled = 0;
            else
                filled = 1;
            end
        end
    end
end
