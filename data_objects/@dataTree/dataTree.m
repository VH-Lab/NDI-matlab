function d = dataTree(name,data,type)
% DATATREE - Create a new DATATREE abstract object
%
%  D = DATATREE(NAME)
%
%  Creates a new DATATREE object with the name NAME.
%  This is an abstract class that is overridden by specific type of format of data.
%
if nargin==1,
    root = [];
    dataTree_struct = struct('name',name,'root',root,'type','undefinited'); 
    d = class(dataTree_struct, 'dataTree');
elseif nargin==2,
    root = constructTree(data);
    dataTree_struct = struct('name',name,'root',root,'type','undefinited'); 
    d = class(dataTree_struct, 'dataTree');
elseif nargin==3,
    root = constructTree(data);
    dataTree_struct = struct('name',name,'root',root,'type',type); 
    d = class(dataTree_struct, 'dataTree');
end

