function s=NSD_dir(dirname)
% NSD_DIR - Create a new NSD experiment object based on a directory
%
% S=NSD_DIR(DIRNAME) creates a new NSD object. The experiment is linked to 
% the file directory DIRNAME.
%

S = NSD(dirname);
NSD_dir_struct = struct('dirname',dirname);

s = class(NSD_dir_struct,'NSD_dir',S);

