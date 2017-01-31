function dt = dataTree_withdir(exp, filetype)
% DATATREE_WITHDIR - Create a new DATATREE_FLAT object
%
%  DT = DATATREE_WITHDIR(EXP)   
%
%  Creates a new data tree object with the experiments 
%  This class in inhereted from datatree and with directory organization
%

s = struct('filetype',filetype);

dt = class(s,'dataTree_flat',dataTree(exp));

