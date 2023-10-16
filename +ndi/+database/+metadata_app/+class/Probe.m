classdef (Abstract) Probe < handle
    properties
        Name
        DeviceType
    end
    
    methods
        % Constructor
        function obj = Probe(name, deviceType)
            if nargin > 0
                obj.Name = name;
                obj.DeviceType = deviceType;
            end
        end
        
        function updateProperty(obj, name, value)
            obj.(name)=value;
        end

        function property = getProperty(obj, name)
            property = obj.(name);
        end
        
        function properties = getProperties(obj)
            properties = struct(...
                'Name', obj.Name, ...
                'DeviceType', obj.DeviceType ...
            );
        end
    end
end
