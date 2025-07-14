function c = writetablechar(t,varargin)
% writetablechar - write a table to a character array
%
% C = writetablechar(T, ...)
%
% Write a Matlab table object to a character array. Passes extra arguments
% to writetable() so that all the arguments to writetable() can be used to
% writetablechar.
% 
% Example:
%   t = array2table(rand(10,3))
%   c = ndi.database.fun.writetablechar(t,...
%      'Delimiter','\t','WriteVariableNames',false);
%   t2 = ndi.database.fun.readtablechar(c,'.txt','Delimiter','\t')
%   diffs = abs(t{:,:}-t2{:,:});
%   does_it_match = all(diffs(:)<1e-15) % does it meet tolerance?
%
% See also: writetable, readtable, ndi.database.fun.readtablechar
%

fname = ndi.file.temp_name();

writetable(t,fname,varargin{:});

realfile = dir([fname '.*']); % it will have an extension

realfilename = fullfile(realfile(1).folder,realfile(1).name);

c = fileread(realfilename);

delete(realfilename);
