function nsd_test_markgarabge
% NSD_TEST_MARKGARBAGE - Test the functionality of the app 'nsd_markgarbage'
%
%  NSD_TEST_MARKGARBAGE
%
%  Tests the NSD_APP_MARKGARBAGE on example data in
%  [NSDCOMMONPATH]/example_app_experiments/markgarbage_ex
%
%

if nargin<1,
	nsd_globals;
	dirname = [nsdcommonpath filesep 'example_app_experiments' filesep 'markgarbage_ex'];
end;

disp(['creating a new experiment object at path ' dirname '...']);
exp = nsd_experiment_dir('exp1_markgarbage_eg',dirname);

disp(['Now adding our acquisition device (intan):']);

  % Step 1: Prepare the data tree; we will just look for .rhd
  %         files in any organization within the directory

dt = nsd_filetree(exp, {'.*\.rhd\>','.*\.epochmetadata\>'},...
		'nsd_epochcontents_iodevice','.*\.epochmetadata\>');  % look for .rhd files

  % Step 2: create the iodevice object and add it to the experiment:

  % if it is there from before, remove it
devs = exp.iodevice_load('name','(.*)');
for i=1:numel(devs), 
	exp.iodevice_rm(celloritem(devs,i));
end;

dev1 = nsd_iodevice_mfdaq_intan('intan1',dt);
exp.iodevice_add(dev1);

  % Step 3: create a markgarbage app

gapp = nsd_app_markgarbage(exp);

 % now mark a region as garbage

rec_probe = getprobes(exp, 'name', 'cortex', 'reference', 1);

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

exp.iodevice_rm(dev1); % remove the iodevice so the demo can run again


