classdef nsd_device_image_tiffstack < nsd_device_image
    %nsd_device_image_tiffstack is a driver used to read images from a tif
    %format.
    %   This class is able to return a frame at a specific epoch, and the numnber of
    %   frames in a specific epoch.

    properties
    end

    methods
        %Constructoe requiers only name and data tree as it uses the super
        %constructor
        function obj = nsd_device_image_tiffstack(name, filetree)
                obj = obj@nsd_device_image(name,filetree);
        end

        %This function returns a specific frame at position 'i' in epoch
        %number 'n'. It acesses the file using the filetree
        function im = frame(obj,n,i)
            epochn_directory = obj.filetree.getepochfiles(n);
            epochn_tiff_file = epochn_directory{1};
            epochn = Tiff(epochn_tiff_file,'r');
            epochn.setDirectory(i);
            im = epochn.read;
            epochn.close;
        end
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
        end


    end
end
