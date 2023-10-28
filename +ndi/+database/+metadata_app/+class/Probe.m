classdef (Abstract) Probe <  handle  %matlab.mixin.Heterogeneous
    properties
        Name
        DeviceType
        ProbeType
        ClassType
        Description
        DigitalIdentifier
        Manufacturer
        Complete
    end
    
    methods
       
        function obj = Probe()
            obj.DeviceType = " ";
        end

        function updateProperty(obj, name, value)
            obj.(name)=value;
        end

        function property = getProperty(obj, name)
            property = obj.(name);
        end

        function s = toTableStruct(obj)
            s = struct();
            s.ProbeName = obj.Name;
            s.ProbeType = obj.ProbeType;
            if obj.Complete
                s.Status = 'Complete';
            else
                s.Status = 'Incomplete';
            end
        end

        function manufacturerName = getManufacturerName(obj)
            if isfield(obj.Manufacturer, 'Name')
                manufacturerName = obj.Manufacturer.Name;
            else
                manufacturerName = ' ';
            end
        end

        function [digitalIdentifier, digitalIdentifierType] = getDigitalIdentifier(obj)
            if ~isfield(obj.DigitalIdentifier, 'Type')
                digitalIdentifierType = 'Select type';
                digitalIdentifier = '';
            else
                digitalIdentifierType = obj.DigitalIdentifier.Type;
                digitalIdentifier = obj.DigitalIdentifier.Value;
            end
        end

        function [digitalIdentifier, digitalIdentifierType] = setDigitalIdentifier(obj, digitalIdentifierType, digitalIdentifier)
            obj.DigitalIdentifier.Type = digitalIdentifierType;
            obj.DigitalIdentifier.Value = digitalIdentifier;
        end
        
        function properties = getProperties(obj)
            properties = struct(...
                'Name', obj.Name, ...
                'DeviceType', obj.DeviceType ...
            );
        end
    end
end
