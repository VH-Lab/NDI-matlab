function s=sampleAPI_dir(dirname)
% SAMPLEAPI_DIR - Create a new SAMPLEAPI experiment object based on a directory
%
% S=SAMPLEAPI_DIR(DIRNAME) creates a new sampleAPI object. The experiment is linked to 
% the file directory DIRNAME.
%

S = sampleAPI(dirname);
sampleAPI_dir_struct = struct('dirname',dirname);

s = class(sampleAPI_dir_struct,'sampleAPI_dir',S);

