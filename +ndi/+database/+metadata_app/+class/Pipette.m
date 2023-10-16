classdef Pipette < ndi.database.metadata_app.class.Probe
    properties
        DigitalIdentifier
        Manufacturer
        Description
        ExternalDiameter
        InternalDiameter
    end
    
    methods
        function obj = Pipette(name, deviceType, digitalIdentifier, manufacturer, description, externalDiameter, internalDiameter)
            obj@ndi.database.metadata_app.class.Probe(name, deviceType);
            % obj.Description = description;
            % obj.ExternalDiameter = externalDiameter;
            % obj.InternalDiameter = internalDiameter;
            % obj.DigitalIdentifier = digitalIdentifier;
            % obj.Manufacturer = manufacturer;
        end

       
    end
end
