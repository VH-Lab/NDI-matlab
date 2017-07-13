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
            epochn_tiff_file = epochn_directory{1}; %gets the string vector with the files path
            fileStatus = checkFile(epochn_tiff_file, fileID);%checks if the file exists, and whether it changed.

            if fileStatus == 1%In case the file exists, but its content has changed, the function displays an error.
              disp(['Epoch number ' num2str(n) 'has changed.']);

            %In case the file exists and is the same, or the file is a new file
            else
              if file2big(epochn_tiff_file)%Checks if the file is over 4GB

                if fileStatus == -1%If the file did not exist and is a new file, execute a bigread2 functionality.
                  info = imfinfo(epochn_tiff_file);%extracts the metadata of the file.
                  totNumFrame = max(size(info));%gets the total number of ferames in the file.
                  ofds = zeros(1,totNumFrame);%a matrix to hold the offset of the first strip in each frame
                  for j=1:numFrames%writing all the offsets of the first strip in each frame into ofds matrix
                      ofds(j)=info(j).StripOffsets(1);
                  end

                  %% Organizing the meta data of the file so it could be read using fread().
                  bd = info.BitDepth;
                  if (bd==64)%translating the bit depth from a number into a string vector so it fits arguments of fread()
                      info.BitDepth ='double';
                  elseif (bd==32)
                      info.BitDepth='single';
                  elseif (bd==16)
                      info.BitDepth='uint16';
                  elseif (bd==8)
                      info.BitDepth='uint8';
                  end

                  if strcmpi(info.BitDepth,'double')%takes care of a special case in which the bit depth is double
                    form = 'single';
                    if strcmp(info.ByteOrder,'big-endian')
                      byteOrder = 'ieee-be.l64';
                    else
                      byteOrder = 'ieee-le. l64';
                    end
                    %translating the byte ore of the file so it matches arguments of fread()
                  else
                    if strcmp(info.ByteOrder,'big-endian');
                      byteOrder = 'ieee-be';
                    else
                      byteOrder = 'ieee-le';
                    end
                      form = info.BitDepth;
                  end
                  %
                  %% reading the data and writing it the image to the memory

                  tmp1 = fread(fp, [info.Width info.Height], form, ofds(i), byteOrder);
                  im = cast(tmp1,form);

                  cache{n} = {'large',epochn_directory,fileID, ofds,info};
                else

                end
              else
                epochn = Tiff(epochn_tiff_file,'r');
                epochn.setDirectory(i);
                im = epochn.read;
                epochn.close;
                chache{n} = {'small',epochn_directory,fileID};
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
