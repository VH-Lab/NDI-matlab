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
      if nargin > 2
        index = obj.find(epochn_directory,fileID);
        if index == -1
          error('Data does not exist in cache');
        else
          data = obj.dataArray{index};
        end
      else
        epochnumber = epochn_directory;
        if isempty(obj.dataArray{epochnumber})
          error('Data does not exist in cache');
        else
          data = obj.dataArray{epochnumber};
        end
      end
    end%getCachedImage

    function obj = add(obj, data, epochnumber)
      obj.dataArray{epochnumber} = data;
    end%add

    function obj = remove(obj, data)
      index = obj.find(data);
      obj.dataArray{index} = [];
    end%remove

    function fileStatus = checkFile(obj, data, epochn_directory, fileID, n)
      % output possibilities:
      % 0 - same file
      % -1 - same name, but file changed
      % 1 - same file, but diff name
      fileStatus = 1;
    end%checkFile

    function index = find(obj, data, fileID)
      index = -1;
      if nargin < 3 && isa(data, 'nsd_image')
        for i = 1:size(obj.dataArray)
          if dataArray{i}.compareTo(data)
            index = i;
          end
        end
      elseif nargin == 3 && ischar(data{1})
        epochn_directory = data;
        for i = 1:size(obj.dataArray)
          if obj.dataArray{i}.compareTo(epochn_directory,fileID)
            index = i;
          end
        end
      else
        error('Wrong use of the find function');
      end
    end%find

    function empty = isEmpty(obj)
      empty = isempty(obj.dataArray);
    end%isEmpty

  end%methods
end%classdef
