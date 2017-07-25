classdef nsd_image < handle

  properties (Access = private)
  fileID;
  epochn_directory;
  image;
  end%properties

  methods
    function obj = nsd_image(epochn_directory, fileID)
      obj.epochn_directory = epochn_directory;
      obj.fileID = fileID;
      obj.image = [];
    end%constructor
    function epochn_directory = getEpochDir(obj)
      epochn_directory = obj.epochn_directory;
    end%getFileDir
    function fileID = getFileID(obj)
      fileID = obj.fileID;
    end%getFileID
    function frame = read(obj,i)
      if isempty(obj.image)
        [~,~,extention] = fileparts(obj.epochn_directory{1});
        switch extention%many possible image formats can be added here.
        case {'.tif','.tiff'}
          obj.image = nsd_image_tiffstack(obj.epochn_directory);
        otherwise
          obj.image = nsd_image_matlab(obj.epochn_directory);
        end
      end
      frame = obj.image.read(i);
    end%read

  end%methods

end%classdef
