classdef DeviceType < handle
    %DEVICETYPE Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Name
        Definition
        Description
        Synonym
    end

    methods
        function obj = DeviceType(name)
            obj.Name = name;
        end

        function updateProperty(obj, name, value)
            obj.(name)=value;
        end

        function Property = getProperty(obj, name)
            Property =  obj.(name);
        end

        function properties = getProperties(obj)
            properties = struct(...
                'Name', obj.Name, ...
                'Definition', obj.Definition, ...
                'Description', obj.Description, ...
                'Synonym', obj.Synonym ...
                );
        end
    end
end

