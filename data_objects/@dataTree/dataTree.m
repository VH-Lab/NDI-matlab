function d = dataFactory(exp)
% DATATREE - Create a new DATATREE abstract object
%
%  D = DATATREE(EXP)   
%
%  Creates a new DATATREE object with the name NAME.
%  This is an abstract class that is overridden by specific type of format of data.
%

dataTree_struct = struct('exp',exp);
d = class(dataTree_struct, 'dataTree');

