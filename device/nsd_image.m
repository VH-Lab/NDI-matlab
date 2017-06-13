classdef (Abstract) nsd_device_image < nsd_device
    % An abstract class defining the main functions of the device image drivers. (frame and numframe)
    %Designed to be a superclass of the specific drivers (eg. nsd_device_image_tiffstack)
    
    properties
    end

    methods
        function obj = nsd_device_image(name,datatree)
            obj = obj@nsd_device(name,datatree);
        end
    end
    
    methods (Abstract)
        im = frame(obj,n,i) % returns the image i from the epoch n of an experiment.
        num = numFrame(obj,n) % retunes the number of frames that an epoch n has.
    end

    
end
