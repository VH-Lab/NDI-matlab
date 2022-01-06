function run_Linux_checks
% RUN_LINUX_CHECKS - run any Linux compatibility checks 
%
% RUN_LINUX_CHECKS
%
% Run Linux compatibility checks and provide any warnings needed.
%
%

archstr = computer('arch');

if strcmpi(archstr,'GLNXA64'), % Linux
	v = ver('MATLAB');
	if strcmpi(v(1).Version,'9.11'),
		warning(['MATLAB 2021b has an incompatibility with Ubuntu 20.04 that can cause crashes when using tools that depend upon Simulink, as NDI does.']);
		warning(['See https://www.mathworks.com/matlabcentral/answers/1567188-simulink-crash-in-ubuntu-20-04']);
		warning(['Also https://www.mathworks.com/support/bugreports/2632298?s_eid=ebre_2632298']);
		warning(['In short, recommended solutions are to run Matlab 2021a, to use Ubuntu 21.04, or add the following code to your startup.m file: open_system(new_system(''abcdef123456'')); bdclose(''abcdef123456'').']);
	end;
end;
