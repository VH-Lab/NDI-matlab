function nsd_test_time_conversion(dirname)
% NSD_TEST_TIME_CONVERSION - Test the functionality of nsd_clock, nsd_synctable
%
%  NSD_TEST_TIME_CONVERSION([DIRNAME])
%
%  Given an experiment directory, this function loads stimulus information
%  and then plots some data from a probe relative to that stimulus information.
%
%  If DIRNAME is not provided, then 'test_vhlabstim_cedspike2' in directory
%  [NSDPATH filesep 'example_experiments' ] is used.
%

if nargin<1,

	nsd_globals;

	mydirectory = [nsdpath filesep 'example_experiments' ];
	dirname = [mydirectory filesep 'test_vhlabstim_cedspike2'];
end;

disp(['reading an experiment object from directory ' dirname ' ... ' ]);
exp = nsd_experiment_dir(dirname);

vhlabstim1 = exp.device_load('name','vhlabstim1');
spike2= exp.device_load('name','spike2');

data = vhlabstim1.readevents('marker',1,1,0,Inf);


keyboard


if 0,

	dev1 = exp.device_load('name','spike2'),

	data = readchannels_epochsamples(dev1,{'analog_in'},1,1,0,Inf);
	time = readchannels_epochsamples(dev1,{'timestamp'},1,1,0,Inf);

	figure;
	plot(time,data);
	ylabel('Data');
	xlabel('Time (s)');
	box off;

end
