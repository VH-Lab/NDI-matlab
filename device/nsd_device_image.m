classdef (Abstract) nsd_device_image < nsd_device
    %This is an abstract superclass of all imaging device drivers
    %This class defines the fundumental functions that the drivers should implement (frame, and numframe)

    properties
    end

    methods
        function obj = nsd_device_image(name,datatree)
            obj = obj@nsd_device(name,datatree);
        end
    end

    methods (Abstract)
        %This function returns a specific fram 'i' from epoch 'n'
        im = frame(obj,n,i)
        %This function returns the number of frames in epoch 'n'
        num = numFrame(obj,n)
    end


end
