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
    function image = read(obj)
      if ~isempty(obj.image)
        image = obj.image;
      else
        %return proper image
      end
    end%read

  end%methods

end%classdef
