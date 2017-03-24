function [ files ] = SATI_vhintan( name,exp )
%SATI_VHINTAN - specific method for intan device to obtain related files
%for any experiment
%   FILES = SATI_VHINTAN(NAME,EXP)
%   FILES = SATI_VHINTAN(NAME,PARENTDIRNAME)
%   sATI_vhintan can:
%   1. query the experiment to identify the files to read 
%   2. based on the parent directory,identify all the files to read
    
if isa(exp,'NSD_device')     %%input is a exp
    dir = get_experiment_directory(exp);
    files = filenames(dir,'rhd');
    
else       %%input is a parentdirname
    files = filenames(exp,'rhd');
    
end


end

