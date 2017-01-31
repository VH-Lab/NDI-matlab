function dt = dataTree(exp)
% DATATREE - Create a new DATATREE abstract object
%
%  DT = DATATREE(EXP)   
%
%  Creates a new DATATREE object with the experiment name.
%  This is an abstract class that is overridden by specific type of format of data.
%

dataTree_struct = struct('exp',exp);
dt = class(dataTree_struct, 'dataTree');

