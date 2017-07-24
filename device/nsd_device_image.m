classdef nsd_device_image < nsd_device
    %This is an abstract superclass of all imaging device drivers
    %This class defines the fundumental functions that the drivers should implement (frame, and numframe)

    properties
    end

    methods
        function obj = nsd_device_image(name,filetree)
            obj = obj@nsd_device(name,filetree);
        end
    end

    methods
        %This function returns a specific fram 'i' from epoch 'n'
        function im = frame(obj,n,i)
          imageFile = loadImage(getepochfiles(n));
          im = imageFile.read;
        %This function returns the number of frames in epoch 'n'
        function num = numFrame(obj,n)
    end


end
