function [b,msg] = assert(ndi_global_variables, varargin)
% ndi.globals.assert - check that ndi_globals has been initialized properly
% 
% [B,MSG] = ndi.globals.assert(ndi_global_variables, ...)
%
% Returns true if the variable ndi_global_variables has been initialized properly. 
% Returns 0 otherwise, and, by default, triggers an error.
% Also returns the error message in MSG, if applicable. If there was no error,
% MSG is empty.
%
% This function takes name/value pairs that modify its default behavior:
% ------------------------------------------------------------------------------
% | Parameter (default)          | Description                                 |
% |------------------------------|---------------------------------------------|
% | generateError (1)            | 0/1 Should we generate a Matlab error call  |
% |                              |        and message? (0=no, 1=yes)           |
% | tryToInit (1)                | 0/1 Should we try to initialize ndi by      |
% |                              |        calling ndi_Init if globals are not  |
% |                              |        set up?                              |
% |----------------------------------------------------------------------------|
% 

  % set up default parameters
generateError = 1;
tryToInit = 1;

 % assign any parameter values specified by the user
vlt.data.assign(varargin{:});

b = 1;
msg = '';

if ~isstruct(ndi_global_variables),
	b = 0;
	msg = 'ndi_globals is not a structure, indicating that it was not initialized.';
end;

if tryToInit & ~b,
	ndi_Init;
	ndi.globals;
	[b,msg] = ndi.globals.assert(ndi_globals,'tryToInit',0,'generateError',generateError);
end;

if generateError & ~b,
	error(['ndi_globals was found not to be initialized as was expected. ' ...
		'Please ensure that your startup file calls ndi_Init. This is commonly done via vhtools startup.']);
end;


