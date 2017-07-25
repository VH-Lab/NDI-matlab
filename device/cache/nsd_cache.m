classdef nsd_cache < handle
  properties (Access = private)
    dataArray;
    end%properties
  methods
    function obj = nsd_cache
      obj.dataArray = {};
    end%constructor

    function exist = exists(obj, epochn_directory, fileID, n)
      exist = 0;
      for i = 0:size(dataArray)
        if dataArray{i}.compareTo(epochn_directory,fileID)
          exist = 1;
        end
      end

    end%exists

    function image = getCachedImage(obj, epochn_directory, fileID)
    end%getImage

    function obj = add(obj, data)
      obj.dataArray{end+1} = data;
    end%add

    function obj = remove(obj, image)
    end%remove

    function fileStatus = checkFile(obj, image)
    end%checkFile

  end%methods
end%classdef
