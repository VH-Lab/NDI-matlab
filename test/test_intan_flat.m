function test_intan_flat(dirname)
% TEST_INTAN_FLAT - Test the functionality of the Intan driver and a data tree with a flat organization
%
%  TEST_INTAN_FLAT([DIRNAME])
%
%  Given a directory with RHD data inside, this function loads the
%  channel information and then plots some data from channel 1,
%  as an example of the Intan driver.
%
%  If DIRNAME is not provided, the default directory
%  [USERPATH/tools/NSD/example_experiments/exp1_eg] is used.
%
%

if nargin<1,

	mydirectory = [userpath filesep 'tools' filesep 'NSD' ...
                filesep 'example_experiments' ];
	dirname = [mydirectory filesep 'exp1_eg'];

end;

disp(['creating a new experiment object...']);
exp = nsd_experiment_dir('exp1',dirname);

disp(['Now adding our acquisition device (intan):']);

  % Step 1: Prepare the data tree; we will just look for .rhd
  %         files in any organization within the directory

dt = nsd_datatree(exp, '.*\.rhd\>');  % look for .rhd files

  % Step 2: create the device object:






disp(['We will now display all the epoches from this datatree:']);

disp(['the experiments are:]');
getExperiment(defaultTree)

disp(['the epoches are:]');
getEpoch(defaultTree)

disp(['get the first epoch from the flat tree:]');
getEpoch(flatTree,1)

%withdir tree

disp(['create a new withdir datatree with dirname ''exp1''']);
withdirTree = dataTree('exp1');

disp(['We will now display the experiment and all the epoches from this datatree:']);

disp(['the experiments are:]');
getExperiment(withdirTree)

disp(['the epoches are:]');
getEpoch(withdirTree,intmax)

disp(['get the first epoch from the withdir tree:]');
getEpoch(withdirTree,1)


%%%%%%%%%%%%%%%%%%%%%%%test nsd devices' default method%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(['Opening a new example NSD with dirname ''exp1''']);
myExp = NSD_dir(dirname);

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize devices ''NSD_intan_flat'' ']);

myExp_tree= nsd_datatree_flat(myExp);

dev1 = NSD_intan_flat(myExp,myExp_tree);

%%test its default methods
files = dev1.getepochfiles(1);

records = dev1.getepochrecord(1);

dev1.deleteepoch(1);

dev1.setepochrecord(1,2,1);

sample_epoch = nsd_epochrecord ('epoch1',~,'aux','dev2');

dev1.verifyepochrecord(sample_epoch,1);


%%%%%%%%%%%%%%%%%%%%%%%test nsd intan_flat extended method%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Now will print all the channels :');

disp ( struct2table(getchannels(dev1)) );

disp ( getintervals(dev1) );

% disp(['Examining the amplifier channels versus time:']);

myClock = NSD_clock(dev1,1);

result1 = read_channel(dev1,'digitalin',1,myClock,0,Inf);

result2 = read_channel(dev1,'timestamp',1,myClock,0,Inf);

channel = 'ai0';
sr = getsamplerate(dev1,1,'aux',channel),
