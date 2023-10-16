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
        
        function properties = toStruct(obj)
            properties = struct(...
                'Name', obj.Name ...
            );
        end
    end
end

