function console(filename)
% CONSOLE - pop up an external terminal window that displays a log file
%
% CONSOLE(FILENAME)
%
% Pops up a console window that displays a log file.
%
% Right now, only MacOS is supported.
%

if ismac(),
	f = ndi.file.temp_name();
	s = {'tell application "Terminal"'};
	s{end+1} = [sprintf('\t') 'activate'];
	s{end+1} = [sprintf('\t') 'set shell to do script "tail -f ' ...
		filename '"'];
	s{end+1} = ['end tell'];
	vlt.file.cellstr2text(f,s);
	system(['osascript ' f]);
elseif isunix(),
	error(['Linux/Unix not supported yet.']);
elseif iswin(),
	error(['Windows not supported yet.']);
end;


