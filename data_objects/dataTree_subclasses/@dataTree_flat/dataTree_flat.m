function dt = dataTree_flat(exp, filetype)

  % docs 

s = struct('filetype',filetype);

dt = class(s,'dataTree_flat',dataTree(exp));

