function [i0,t0,filename] = interval_find_files(dir,t)
% INTERVAL_FIND_FILES - find the files that after the input interval time
%
%   [I0, T0] = INTERVAL_FIND_FILES(DIR,T) checks the files in that
%   directory and compare their interval relative time with input t
%


    filenames = {};

    d = dirstrip(dir(dir));


    for i=1:length(d),
        if d(i).isdir, 
            filenames = cat(1,filenames,...
                interval_relative_time([pathname filesep d(i)],t));
        else,
            [mydir,byname,myext] = fileparts(d(i)); %%get the name of files
            cel = strsplit(mydir,'-')         
            if str2num(cel(end)) == t,              %%check with the input time t
                i0 = [pathname filesep(d(i))];      %?should i0 and t0 be specific time or specific filename
            else if str2num(cel(end)) < t,
                filenames{end+1} = [pathname filesep(d(i))];
        end;
    end;
