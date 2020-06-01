function build_intan_flat_exp(dirname)
% BUILD_INTAN_FLAT_EXP - Create an Intan driver and save it to an session
%
%  BUILD_INTAN_FLAT_EXP([DIRNAME])
%
%  Given a directory with RHD data inside, this function loads the
%  channel information and then plots some data from channel 1,
%  as an example of the Intan driver. It also leaves the driver saved
%  in the session record.
%
%  If DIRNAME is not provided, the default directory
%  [NDIPATH]/example_sessions/exp1_eg_saved is used.
%

if nargin<1,
	ndi_globals;
	dirname = [ndi.path.exampleexperpath filesep 'exp1_eg_saved'];
end;

disp(['creating a new session object...']);
E = ndi_session_dir('exp1',dirname);

 % remove everyelement from the session to start
E.database_clear('yes'); % use it only if you mean it

dev = E.daqsystem_load('name','(.*)'), 
if ~isempty(dev) & ~iscell(dev),
	dev = {dev};
end;
for i=1:numel(dev),
	E.daqsystem_rm(dev{i});
end;

disp(['Now adding our acquisition daqsystem (intan):']);

  % Step 1: Prepare the data tree; we will just look for .rhd
  %         files in any organization within the directory

dt = ndi_filenavigator(E, '.*\.rhd\>');  % look for .rhd files

  % Step 2: create the device object and add it to the session:

dev1 = ndi_daqsystem_mfdaq('intan1',dt,ndi_daqreader_mfdaq_intan());
E.daqsystem_add(dev1);

subject = ndi_subject('anteater27@nosuchlab.org','');
E.database_add(subject.newdocument());
 
  % Step 3: let's add a document

doc = E.newdocument('ndi_document_subjectmeasurement',...
	'ndi_document.name','Animal statistics',...
	'subject.id','vhlab12345', ...
	'subject.species','Mus musculus',...
	'subjectmeasurement.measurement','age',...
	'subjectmeasurement.value',30,...
	'subjectmeasurement.datestamp','2017-03-17T19:53:57.066Z'...
	);

 % add it here
E.database_add(doc);

  % Now let's print some statistics

disp(['The channels we have on this device are the following:']);

disp ( struct2table(getchannels(dev1)) );

sr_d = samplerate(dev1,1,{'digital_in'},1);
sr_a = samplerate(dev1,1,{'analog_in'},1);

disp(['The sample rate of digital channel 1 in epoch 1 is ' num2str(sr_d) '.']);
disp(['The sample rate of analog channel 1 in epoch 1 is ' num2str(sr_a) '.']);

disp(['We will now plot the data for epoch 1 for analog_input channel 1.']);

data = readchannels_epochsamples(dev1,{'analog_in'},1,1,0,Inf);
time = readchannels_epochsamples(dev1,{'timestamp'},1,1,0,Inf);

figure;
plot(time,data);
ylabel('Data');
xlabel('Time (s)');
box off;

test_intan_flat_saved(dirname)
