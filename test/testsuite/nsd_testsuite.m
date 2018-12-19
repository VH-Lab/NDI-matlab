function output = nsd_testsuite
% NSD_TESTSUITE - run a suite of tests
%
% OUTPUT = NSD_TESTSUITE
%
% Loads a set of test suite instructions in the file
% 'nsd_testsuite_list.txt'. This file is a tab-delimited table
% that can be loaded with LOADSTRUCTARRAY with fields
% Field name          | Description
% -----------------------------------------------------------------
% code                | The code to be run (as a Matlab evaluation)
% runit               | Should we run it? 0/1
%
% OUTPUT is a structure of outcomes. It includes the following fields:
% Field name          | Descriptopn
% -----------------------------------------------------------------
% outcome             | Success is 1, failure is 0.
% errormsg            | Any error message
% code                | The code that was run
%

jobs = loadStructArray('nsd_testsuite_list.txt');

output = emptystruct('outcome','errormsg','code');

for i=1:numel(jobs),
	output_here = output([]);
	output_here(1).errormsg = '';
	output_here(1).outcome = 0;
	output_here(1).code = jobs(i).code;
	if jobs(i).runit,
		try,
			eval(jobs(i).code);
			output_here(1).outcome = 1;
		catch,
			output_here(1).errormsg = lasterr;
		end;
	else,
			output_here(1).outcome = -1; % not run
	end;
	output(end+1) = output_here;
end

for i=1:numel(output),
	if output(i).outcome>0,
		beginstr = ['SUCCESS: '];
		endstr = '';
	elseif output(i).outcome==0,
		beginstr = ['FAILURE: '];
		endstr = output(i).errormsg;
	end;
	if output(i).outcome > 
		disp([beginstr ', Code: ' output(i).code ' ' endstr]);
	end;
end
