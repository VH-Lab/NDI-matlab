classdef (Abstract) nsd_iodevice_image < nsd_device
    % An abstract class defining the main functions of the device image drivers. (frame and numframe)
    %Designed to be a superclass of the specific drivers (eg. nsd_iodevice_image_tiffstack)
    
    properties
    end

    methods
        function obj = nsd_iodevice_image(name,filetree)
            obj = obj@nsd_iodevice(name,filetree);
        end
    end
    
    methods (Abstract)
        im = frame(obj,n,i) % returns the image i from the epoch n of an experiment.
        num = numFrame(obj,n) % retunes the number of frames that an epoch n has.
    end

    
end
