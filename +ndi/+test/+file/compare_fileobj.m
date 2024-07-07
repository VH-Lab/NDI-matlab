function [b] = compare_fileobj(f1,f2)
% COMPARE_FILEOBJ compare the binary contents of fileobj elements
%
% B = COMPARE_FILEOBJ(F1,F2)
%
% Does a binary comparison of the contents of FILEOBJ F1 and F2.
%

arguments
	f1 fileobj
	f2 fileobj
end

buffer_size = 100000;

b = 1;

while ~feof(f1),
	data1 = fread(f1,buffer_size,'char');
	data2 = fread(f2,buffer_size,'char');
	if ~isequal(data1,data2),
		b = 0;
		return;
	end;
end;
