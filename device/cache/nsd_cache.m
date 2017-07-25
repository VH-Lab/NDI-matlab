classdef nsd_cache < handle
  properties (Access = private)
    imageArray;
    end%properties
  methods
    function obj = nsd_cache
      obj.imageArray = {};
    end%constructor
    function exist = exists(obj, epochn_directory, fileID, n)

    end%exists
    function image = getImage(obj, epochn_directory, fileID)

    end%getImage
    function obj = add(obj, image)

    end%add

  end%methods
end%classdef
