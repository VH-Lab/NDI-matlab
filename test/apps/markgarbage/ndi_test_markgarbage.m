function ndi_test_markgarbage
% NDI_TEST_MARKGARBAGE - Test the functionality of the app 'ndi_markgarbage'
%
%  NDI_TEST_MARKGARBAGE
%
%  Tests the NDI_APP_MARKGARBAGE on example data in
%  [NDICOMMONPATH]/example_app_sessions/markgarbage_ex
%
%

if nargin<1,
	ndi_globals;
	dirname = [ndi.path.commonpath filesep 'example_app_sessions' filesep 'markgarbage_ex'];
end;

disp(['creating a new session object at path ' dirname '...']);
E = ndi_session_dir('exp1_markgarbage_eg',dirname);

disp(['Now adding our acquisition device (intan):']);

  % Step 1: Prepare the data tree; we will just look for .rhd
  %         files in any organization within the directory

fn = ndi_filenavigator(E, {'.*\.rhd\>','.*\.epochmetadata\>'},...
		'ndi_epochprobemap_daqsystem','.*\.epochmetadata\>');  % look for .rhd files

  % Step 2: create the daqsystem object and add it to the session:

  % if it is there from before, remove it
devs = E.daqsystem_load('name','(.*)');
for i=1:numel(devs), 
	E.daqsystem_rm(celloritem(devs,i));
end;

dev1 = ndi_daqsystem_mfdaq('intan1',fn,ndi_daqreader_mfdaq_intan());
E.daqsystem_add(dev1);

  % Step 3: create a markgarbage app

gapp = ndi_app_markgarbage(E);

 % now mark a region as garbage

rec_probe = getprobes(E, 'name', 'cortex', 'reference', 1);

gapp.clearvalidinterval(rec_probe{1}); 

[data,t,timeref]=rec_probe{1}.readtimeseriesepoch(1, 0, 1); % read 1 second of data from the first epoch

gapp.markvalidinterval(rec_probe{1}, 1, timeref, 3, timeref); % make only from 1 second to 3 seconds as 'good'

intervals = gapp.identifyvalidintervals(rec_probe{1},timeref,0,Inf),

[data,time,timeref] = rec_probe{1}.readtimeseriesepoch(1, intervals(1,1), intervals(1,2));

figure;
plot(time,data);
ylabel('Data');
xlabel('Time (s)');
box off;

disp(['Now cleaning the example so it can be run again...']);

E.daqsystem_rm(dev1); % remove the daqsystem so the demo can run again


