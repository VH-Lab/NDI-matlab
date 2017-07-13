classdef nsd_device_image_tiffstack < nsd_device_image
    %nsd_device_image_tiffstack is a driver used to read images from a tif
    %format.
    %   This class is able to return a frame at a specific epoch, and the numnber of
    %   frames in a specific epoch.

    properties
    cache;
    end

    methods
        %Constructoe requiers only name and data tree as it uses the super
        %constructor
        function obj = nsd_device_image_tiffstack(name, filetree)
                obj = obj@nsd_device_image(name,filetree);
                chache = {};
        end

        %This function returns a specific frame at position 'i' in epoch
        %number 'n'. It acesses the file using the filetree
        function im = frame(obj,n,i)
            [epochn_directory, fileID] = obj.filetree.getepochfiles(n);
            fileStatus = checkFile(epochn_directory, fileID);
            if fileStatus == 1
              disp(['Epoch number ' num2str(n) 'has changed.']);
            else
              epochn_tiff_file = epochn_directory{1};
              if file2big(epochn_tiff_file)
                %%use bigread2 functionality.
              else
                epochn = Tiff(epochn_tiff_file,'r');
                epochn.setDirectory(i);
                im = epochn.read;
                epochn.close;
              end
              if fileStatus == -1
                chache{n} = {epochn_directory,fileID};
              end
            end
        end%im=frame(obj,n,i)
        function num = numFrame(obj,n)
            epochn_directory = obj.filetree.getepochfiles(n);
            epochn_tiff_file = epochn_directory{1};
            epochn = Tiff(epochn_tiff_file,'r');
            %is there a case of 0 frames? can a Tiff file of 0 frames
            %exist? Not sure how to determine if that is the case.
            num = 1;
            while ~epochn.lastDirectory
                num = num+1;
                epochn.nextDirectory;
            end
            epochn.close;
        end%num = numFrame(obj,n)
        function fileStatus = checkFile(epochn_directory,fileID)
          index = find(contains([self.cache{:}],'epochn_directory'));
          if isempty(index)
            fileStatus = -1;
          else
            index = (index+1)/2;
            if strcmp(self.cache{index}{2}, fileID)
              fileStatus = 0;
            else
              fileStatus = 1;
            end
          end
        end%fileStatus = checkFile(epochn_directory,fileID)
        function isBig = file2big(file_path)
          fileDetails = dir(file_path);
          sizeInGigaBytes = fileDetails.bytes/10^9;
          if sizeInGigaBytes > 4
            isBig = 1;
          else
            isBig = 0;
          end
        end%isBig = file2big(file_path)

    end%methods
end%classdef
