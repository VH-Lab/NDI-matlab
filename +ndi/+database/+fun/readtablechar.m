function t = readtablechar(c,ext,varargin)
% readtablechar - read a table from a character array
%
% t = readtablechar(C,EXT, ...)
%
% Read a Matlab table object from a character array C that would have the file
% extension EXT if it were a file. Passes extra arguments
% to readtable() so that all the arguments to readtable() can be used to
% readtablechar.
% 
% Example:
%   t = array2table(rand(10,3))
%   c = ndi.database.fun.writetablechar(t,...
%      'Delimiter','\t','WriteVariableNames',false);
%   t2 = ndi.database.fun.readtablechar(c,'.txt','Delimiter','\t');
%   diffs = abs(t{:,:}-t2{:,:});
%   does_it_match = all(diffs(:)<1e-15) % does it meet tolerance?
%
% See also: writetable, readtable, ndi.database.fun.writetablechar
%

arguments
    c (1,:) char
    ext (1,:) char {mustBeVector}
end
arguments (Repeating)
    varargin
end

if ext(1)~='.'
    ext = ['.' ext];
end; 

fname = [ ndi.file.temp_name() ext ];

vlt.file.str2text(fname,c);

try
    t = readtable(fname, varargin{:});
catch ME
    delete(fname);
    throw(ME);
end

delete(fname);

