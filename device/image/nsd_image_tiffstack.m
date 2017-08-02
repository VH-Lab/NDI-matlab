classdef nsd_image_tiffstack < handle
  properties (Access = private)
  file_path;
  tiffObject;
  byteOrder;
  bitDepth;
  totnumFrame;
  ofds;
  info;
  big;
  end%properties

  methods
    function obj = nsd_image_tiffstack(epochn_directory)
      obj.file_path = epochn_directory{1};
      if obj.file2big(obj.file_path)
        %large tiff
        [obj.byteOrder, obj.bitDepth, obj.totnumFrame, obj.ofds, obj.info] = self.organizeBigTiffMetaData(obj.file_path);
        obj.big = 1;
      else
        %small tiff
        obj.tiffObject = Tiff(obj.file_path,'r');
        obj.big = 0;
      end
    end%constructor
    function frame = read(obj,i)
      if obj.big
        %read frame as big
        fp = fopen(obj.file_path);
        tmp1 = fread(fp, [obj.info.Width obj.info.Height], obj.bitDepth, obj.ofds(i), obj.byteOrder);
        frame = cast(tmp1,obj.bitDepth);
      else
        %read frame as small
        obj.tiffObject.setDirectory(i);
        frame = obj.tiffObject.read;
      end
    end%read
    function isBig = file2big(obj,file_path)
      fileDetails = dir(file_path);
      sizeInGigaBytes = fileDetails.bytes/10^9;
      if sizeInGigaBytes > 4
        isBig = 1;
      else
        isBig = 0;
      end
    end%isBig = file2big(file_path)
    function num = numFrame(obj)
      if obj.big
        num = obj.totNumFrame;
      else
        obj.tiffObject.setDirectory(1);
        while ~obj.tiffObject.lastDirectory;
          obj.tiffObject.nextDirectory;
        end
        num = obj.tiffObject.currentDirectory;
      end
    end%numFrame


    function [byteOrder, bitDepth, numFrames, ofds, info] = organizeBigTiffMetaData(obj,file_path)
      info = imfinfo(file_path);
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
    end%organizeMetaData()

  end%methods

end%classdef
