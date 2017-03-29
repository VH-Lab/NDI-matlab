function filenames = findfiletype(pathname, extension)
% FINDFILETYPE - Find all files of a given extension in a folder
%
%  FILENAMES = FINDFILETYPE(PATHNAME, EXTENSION)
%
%  Find all the files of a given type in a folder PATHNAME,
%  including subfolders.
%
%  

filenames = {};

d = dirstrip(dir(pathname));


for i=1:length(d),
	if d(i).isdir, 
 		filenames = cat(2,filenames,...
 			findfiletype([pathname filesep d(i).name],extension));
	else,
		[mydir,byname,myext] = fileparts(d(i).name);
        myext = trimsymbol(myext,'.');
		if strcmp(lower(myext),lower(extension))
			filenames{end+1} = [pathname filesep d(i).name];
		end;
	end;
end;

return;


%% can also use a function called geAllFiles for a specific path and then keep the file with wanted extension
% files = getAllFiles(pathname);
% for i = 1:length(files),
%     [mydir,byname,myext] = fileparts(files(i));
%     if strcmp(lower(myext),lower(extension)),
% 		filenames{end+1} = [pathname filesep(files(i))];
%     end
% end

