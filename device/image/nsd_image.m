classdef nsd_image < handle

  properties (Access = private)
  fileID;
  epochn_directory;
  image;
  end%properties

  methods
    function obj = nsd_image(epochn_directory, fileID,format)
      if nargin < 2 || nargin > 3
        error('number of arguments is only 2 or 3');
      end
      obj.epochn_directory = epochn_directory;
      obj.fileID = fileID;
      if nargin == 2
        [~,~,extention] = fileparts(obj.epochn_directory{1});
      elseif nargin == 3
        extention = format;
      end
      switch extention%many possible image formats can be added here.
      case {'.tif','.tiff'}
        obj.image = nsd_image_tiffstack(epochn_directory);
      otherwise
        obj.image = nsd_image_matlab(epochn_directory);
      end%switch
    end%constructor

    function epochn_directory = getEpochDir(obj)
      epochn_directory = obj.epochn_directory;
    end%getFileDir
    function fileID = getFileID(obj)
      fileID = obj.fileID;
    end%getFileID
    function image = getImage(obj)
      image = obj.image;
    end%getImage
    function frame = read(obj,i)
      frame = obj.image.read(i);
    end%read
    function compare = compareTo(obj, image, fileID)
      if nargin == 2
        compare = strcmp(obj.fileID,image.getFileID) && cellfun(@strcmp,obj.epochn_directory, image.getEpochDir);%passes argument to the wrapped image implementation of the function
      elseif nargin == 3
        epochn_directory = image;
        compare = strcmp(obj.fileID,fileID) && cellfun(@strcmp,obj.epochn_directory, epochn_directory);
      end
    end%compareTo

    function num = numFrame(obj)
      num = obj.image.numFrame;
    end%numFrame

  end%methods

end%classdef
