classdef nsd_device_image < nsd_device
    %This is an abstract superclass of all imaging device drivers
    %This class defines the fundumental functions that the drivers should implement (frame, and numframe)

    properties
    cache;
    end

    methods
        function obj = nsd_device_image(name,filetree)
            obj = obj@nsd_device(name,filetree);
        end

        %This function returns a specific frame 'i' from epoch 'n'
        function frame = frame(obj,n,i)
          image = nsd_image(getepochfiles(n));
          if cache.exist(image)
            image = cache.getImage(image);
          end
          frame = image.read(i);
          cache.add(image);
        end%frame
        %This function returns the number of frames in epoch 'n'
        function num = numFrame(obj,n)
        end%numFrame

      end%methods

end%classdef
