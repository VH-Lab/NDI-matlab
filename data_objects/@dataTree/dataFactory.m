function d = dataFactory(name,input_data,type)
% DATATREE - Create a new DATATREE abstract object
%
%  D = DATATREE(NAME)
%
%  Creates a new DATATREE object with the name NAME.
%  This is an abstract class that is overridden by specific type of format of data.
%
if nargin==1,
    data = [];
    dataTree_struct = struct('name',name,'data',data,'type','undefinited'); 
    d = class(dataTree_struct, 'dataTree');
elseif nargin==2,
    data = process(input_data);
    dataTree_struct = struct('name',name,'data',data,'type','undefinited'); 
    d = class(dataTree_struct, 'dataTree');
elseif nargin==3,
    data = process(input_data);
    dataTree_struct = struct('name',name,'data',data,'type',type); 
    d = class(dataTree_struct, 'dataTree');
end

