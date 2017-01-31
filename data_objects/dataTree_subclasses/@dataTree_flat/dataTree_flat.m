function dt = dataTree_flat(exp, filetype)
% DATATREE_FLAT - Create a new DATATREE_FLAT object
%
%  DT = DATATREE(EXP)   
%
%  Creates a new data tree object with the experiment name 
%  This class in inhereted from datatree and with flat organization
%

s = struct('filetype',filetype);

dt = class(s,'dataTree_flat',dataTree(exp));

