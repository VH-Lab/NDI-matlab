classdef DaqSystemCollection < ndi.internal.mixin.JsonSerializable

    properties (Constant)
        VERSION = "1.0.0"
        DESCRIPTION = "NDI DAQ System Configuration Collection" % Catalog?
    end

    properties
        DaqSystems (1,:) ndi.setup.DaqSystemConfiguration
    end

    methods % Catalog-like methods...
        function addDaqSystem(obj)
            obj.DaqSystems(end+1) = ndi.setup.DaqSystemConfiguration();

        end

        function removeDaqSystem(obj, index)
            obj.DaqSystems(index) = [];
        end
    end

    methods (Access = protected)
        % function fromStruct(obj, S)
        % 
        % end

        function tf = isInitialized(obj)
        % isInitialized - Is data initialized?
            tf = ~isempty(obj.DaqSystems);
        end

    end

    methods (Static)
        function obj = fromJson(jsonStr)
            className = mfilename('class');
            obj = fromJson@ndi.internal.mixin.JsonSerializable(jsonStr, className);
        end
    end
end