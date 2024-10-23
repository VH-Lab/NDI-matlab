classdef (Abstract) ndi_image < ndi.daq.system
    % An abstract class defining the main functions of the device image drivers. (frame and numframe)
    % Designed to be a superclass of the specific drivers (eg. ndi_daqsystem_image_tiffstack)

    properties
    end

    methods
        function obj = ndi_image(name,filenavigator)
            obj = obj@ndi.daq.system(name,filenavigator);
        end
    end

    methods (Abstract)
        im = frame(obj,n,i) % returns the image i from the epoch n of an session.
        num = numFrame(obj,n) % retunes the number of frames that an epoch n has.
    end


end
