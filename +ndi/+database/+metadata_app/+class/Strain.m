classdef Strain < handle
    %STRAIN Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Name
    end

    methods
        function obj = Strain(name)
            obj.Name = name;
        end

        function updateProperty(obj, name, value)
            obj.(name)=value;
        end

        function property = getProperty(obj, name)
            property = obj.(name);
        end

        function str = toString(obj)
            str = obj.Name;
        end

        function s = toStruct(obj)
            props = properties(obj);
            s = struct();
            for i = 1:length(props)
                propName = props{i};
                propValue = obj.(propName);
                if isempty(propValue)
                    obj.(propName) = '';
                else
                    s.(propName) = propValue;
                end
            end
        end
    end
    methods (Static)
        function obj = fromStruct(s)
            obj = ndi.database.metadata_app.class.Strain(s.Name);
        end
    end
end

