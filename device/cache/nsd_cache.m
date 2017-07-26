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
      if obj.find(epochn_directory,fileID) ~= -1
        exist = 1;
      end
    end%exists

    function data = getCachedData(obj, epochn_directory, fileID)
      index = obj.find(epochn_directory,fileID);
      if index == -1
        error('Data does not exist in cache');
      else
        data = obj.dataArray{index};
      end
    end%getCachedImage

    function data = getCachedData(obj,epochnumber)
      if isempty(obj.dataArray{epochnumber})
        error('Data does not exist in cache');
      else
        data = obj.dataArray{epochnumber};
      end
    end%getCachedImage

    function obj = add(obj, data, epochnumber)
      obj.dataArray{epochnumber} = data;
    end%add

    function obj = remove(obj, data)
      index = obj.find(data);
      obj.dataArray{index} = [];
    end%remove

    function fileStatus = checkFile(obj, data)
    end%checkFile

    function index = find(obj, data)
      index = -1;
      for i = 1:size(dataArray)
        if dataArray{i}.compareTo(data)
          index = i;
        end
      end
    end%find

    function index = find(obj, epochn_directory, fileID)
      index = -1;
      for i = 1:size(dataArray)
        if dataArray{i}.compareTo(epochn_directory,fileID)
          index = i;
        end
      end
    end%find

    function empty = isEmpty(obj)
      empty = isempty(obj.dataArray);
    end%isEmpty

  end%methods
end%classdef
