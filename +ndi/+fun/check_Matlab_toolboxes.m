function check_Matlab_toolboxes

ndi.globals;

V = ver;

filename = [ndi_globals.path.commonpath filesep 'requirements' filesep ...
	'ndi-matlab-toolboxes.json'];

t = vlt.file.textfile2char(filename);

r = jsondecode(t);

for j=1:numel(r.toolboxes.required),
	index = find(strcmp(r.toolboxes.required(j),{V.Name}));
	if isempty(index),
		warning(['Required toolbox "' char(r.toolboxes.required(j)) '" is not found in your Matlab installation. Key components of NDI-matlab will likely not work.']);
	end;
end;
