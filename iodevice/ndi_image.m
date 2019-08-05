classdef (Abstract) ndi_iodevice_image < ndi_device
    % An abstract class defining the main functions of the device image drivers. (frame and numframe)
    %Designed to be a superclass of the specific drivers (eg. ndi_iodevice_image_tiffstack)
    
    properties
    end

    methods
        function obj = ndi_iodevice_image(name,filenavigator)
            obj = obj@ndi_iodevice(name,filenavigator);
        end
    end
    
    methods (Abstract)
        im = frame(obj,n,i) % returns the image i from the epoch n of an experiment.
        num = numFrame(obj,n) % retunes the number of frames that an epoch n has.
    end

    
end
