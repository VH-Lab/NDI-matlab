classdef nsd_device_image < nsd_device
    %This is an abstract superclass of all imaging device drivers
    %This class defines the fundumental functions that the drivers should implement (frame, and numframe)

    properties
    cache;
    end

    methods
        function obj = nsd_device_image(name,filetree)
          obj = obj@nsd_device(name,filetree);
          obj.cache = nsd_cache;
        end

        %This function returns a specific frame 'i' from epoch 'n'
        function frame = frame(obj,n,i)
          [epochn_directory, fileID] = obj.filetree.getepochfiles(n);
          if obj.cache.exists(epochn_directory, fileID)%should I add a functionality where the cache checks if the imageID and the epochnumber match
            image = obj.cache.getCachedImage(epochn_directory, fileID);
            fileStatus = obj.cache.checkFile(image, epochn_directory, fileID, n);
            if fileStatus == -1 || fileStatus == 0
              cache.updateImage(image, fileStatus);
            end
          else
            image = nsd_image(epochn_directory, fileID);
          end
          frame = image.read(i);
          cache.add(image);
        end%frame
        %This function returns the number of frames in epoch 'n'
        function num = numFrame(obj,n)
          [epochn_directory, fileID] = obj.filetree.getepochfiles(n);
          if obj.cache.exists(epochn_directory, fileID)%should I add a functionality where the cache checks if the imageID and the epochnumber match
            image = obj.cache.getCachedImage(epochn_directory, fileID);
            fileStatus = obj.cache.checkFile(image, epochn_directory, fileID, n);
            if fileStatus == -1 || fileStatus == 0
              cache.updateImage(image, fileStatus);
            end
          else
            image = nsd_image(epochn_directory, fileID);
          end
          num = image.numFrame(n);
        end%numFrame

      end%methods

end%classdef
