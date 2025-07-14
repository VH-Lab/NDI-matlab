classdef ndi_daqsystem_image_tiffstack < ndi_daqsystem_image
    %ndi_daqsystem_image_tiffstack is a driver used to read images from a tif
    % format.
    %   This class is able to return a frame at a specific epoch, and the number of
    %   frames in a specific epoch.

    properties
        cache;
    end

    methods
        % Constructor requires only name and data tree as it uses the super
        % constructor
        function obj = ndi_daqsystem_image_tiffstack(name, filenavigator)
            obj = obj@ndi_daqsystem_image(name,filenavigator);
            cache = {};
        end

        % This function returns a specific frame at position 'i' in epoch
        % number 'n'. It accesses the file using the filenavigator
        function im = frame(obj,n,i)
            [epochn_directory, fileID] = obj.filenavigator.getepochfiles(n);
            epochn_tiff_file = epochn_directory{1}; %gets the string vector with the files path
            fileStatus = obj.checkFile(epochn_tiff_file, fileID);%checks if the file exists, and whether it changed.

            if fileStatus == 1%In case the file exists, but its content has changed, the function displays an error.
                disp(['Epoch number ' num2str(n) 'has changed.']);

                % In case the file exists and is the same, or the file is a new file
            elseif fileStatus == -1%If the file did not exist and is a new file

                if obj.file2big(epochn_tiff_file)%Checks if the file is over 4GB
                    info = imfinfo(epochn_tiff_file);%extracts the metadata of the file.
                    [byteOrder, bitDepth, totnumFrame, ofds, info] = self.organizeBigTiffMetaData(info);

                    %
                    %% reading the data and writing it the image to the memory
                    fp = fopen(epochn_tiff_file);
                    tmp1 = fread(fp, [info.Width info.Height], form, ofds(i), byteOrder);
                    im = cast(tmp1,form);

                    obj.cache{n} = {'large',epochn_tiff_file,fileID,info,ofds};
                else
                    epochn = Tiff(epochn_tiff_file,'r');
                    epochn.setDirectory(i);
                    im = epochn.read;
                    % epochn.close; not sure if I need to delete this line
                    obj.cache{n} = {'small',epochn_tiff_file,fileID,epochn};
                    disp('cached');
                end%file2big
            else
                disp('Frame taken from cache')
                if obj.file2big(epochn_tiff_file)
                    fp = fopen(epochn_tiff_file);
                    info = cache{n}{4};
                    % call organize metadata function
                    tmp1 = fread(fp, [info.Width info.Height], form, ofds(i), byteOrder);
                    im = cast(tmp1,form);
                else
                    epochn = obj.cache{n}{4};
                    epochn.setDirectory(i);
                    im = epochn.read;
                end
            end%fileStatus
        end%im=frame(obj,n,i)
        function num = numFrame(obj,n)
            [epochn_directory, fileID] = obj.filenavigator.getepochfiles(n);
            epochn_tiff_file = epochn_directory{1};
            fileStatus = obj.checkFile(epochn_tiff_file, fileID);
            if fileStatus == 1%In case the file exists, but its content has changed, the function displays an error.
                disp(['Epoch number ' num2str(n) 'has changed.']);
                num = -1;
            elseif fileStatus == -1
                if obj.file2big(epochn_tiff_file)
                    info = imfinfo(epochn_directory);
                    num = max(size(info));
                else
                    epochn = Tiff(epochn_tiff_file,'r');
                    % is there a case of 0 frames? can a Tiff file of 0 frames
                    % exist? Not sure how to determine if that is the case.
                    while ~epochn.lastDirectory
                        epochn.nextDirectory;
                    end
                    num = epochn.currentDirectory;
                    % epochn.close;
                end
            else
                disp('Number of frames retrieved from cache');
                if strcmp(obj.cache{n}{1}, 'large')
                    num = max(size(cache{n}{4}));
                else
                    if size(obj.cache) == 5
                        num = obj.cache{n}{5};
                    else
                        epochn = obj.cache{n}{4};
                        while ~epochn.lastDirectory
                            epochn.nextDirectory;
                        end
                        num = epochn.currentDirectory;
                        obj.cache{n}{5} = num;
                    end
                end
            end
        end%num = numFrame(obj,n)
        function fileStatus = checkFile(obj,epochn_tiff_file,fileID)
            %index = find(contains(obj.cache{:}{2},epochn_tiff_file));
            index = -1;
            for i = 1:numel(obj.cache)
                if contains(obj.cache{i}{2},epochn_tiff_file)
                    index = i;
                end
            end
            if index == -1
                fileStatus = -1;
            else
                if strcmp(obj.cache{index}{3}, fileID)
                    fileStatus = 0;
                else
                    fileStatus = 1;
                end
            end
        end%fileStatus = checkFile(epochn_directory,fileID)

        function isBig = file2big(obj,file_path)
            fileDetails = dir(file_path);
            sizeInGigaBytes = fileDetails.bytes/10^9;
            if sizeInGigaBytes > 4
                isBig = 1;
            else
                isBig = 0;
            end
        end%isBig = file2big(file_path)

        function [byteOrder, bitDepth, numFrames, ofds, info] = organizeBigTiffMetaData(obj,info)
            totNumFrame = max(size(info));%gets the total number of ferames in the file.
            ofds = zeros(1,totNumFrame);%a matrix to hold the offset of the first strip in each frame
            for j=1:numFrames%writing all the offsets of the first strip in each frame into ofds matrix
                ofds(j)=info(j).StripOffsets(1);
            end

            %% Organizing the meta data of the file so it could be read using fread().%thinking about making it a function of its own
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
                    byteOrder = 'ieee-le.l64';
                end
                % translating the byte order of the file so it matches arguments of fread()
            else
                if strcmp(info.ByteOrder,'big-endian')
                    byteOrder = 'ieee-be';
                else
                    byteOrder = 'ieee-le';
                end
                form = info.BitDepth;
            end
        end%organizeMetaData()

    end%methods
end%classdef
