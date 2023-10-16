classdef Electrode < ndi.database.metadata_app.class.Probe
    properties
        DigitalIdentifier
        Manufacturer
        Description
        IntrinsicResistance
    end
    
    methods
        function obj = Electrode(name, deviceType, digitalIdentifier, manufacturer, description, intrinsicResistance)
            obj@ndi.database.metadata_app.class.Probe(name, deviceType);
            obj.DigitalIdentifier = digitalIdentifier;
            obj.Manufacturer = manufacturer;
            obj.Description = description;
            obj.IntrinsicResistance = intrinsicResistance;
        end
    end

       
end

