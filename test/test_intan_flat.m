function test_intan_flat(dirname)
% TEST_INTAN_FLAT - Test the functionality of the Intan driver
%
%  TEST_INTAN_FLAT(DIRNAME)
%
%  Given a directory with RHD data inside, this function loads the
%  channel information and then plots some data from channel 1,
%  as a test of the Intan Flat driver.
%
%  

%%%%%%%%%%%%%%%%%%TEST DATATREE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%default tree
disp(['create a new default datatree with dirname ''exp1''']);
defaultTree = dataTree('exp1');

disp(['We will now display the experiment and all the epoches from this datatree:']);

disp(['the experiments are:]');
getExperiment(defaultTree)

disp(['the epoches are:]');
getEpoch(defaultTree)

%flat tree

disp(['create a new flat datatree with dirname ''exp1''']);
flatTree = dataTree('exp1');

disp(['We will now display the experiment and all the epoches from this datatree:']);

disp(['the experiments are:]');
getExperiment(flatTree)

disp(['the epoches are:]');
getEpoch(flatTree,intmax)

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

%%%%%%%%%%%%%%%%%%NSD WITH DATAREE%%%%%%%%%%%%%%%%%%%%%%%%%%

...









%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% this function works as a sample test function specifically for the 
%% intan_flat daq


disp(['Opening a new example NSD with dirname ''exp1''']);
myExp = NSD_dir(dirname);

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize devices ''NSD_intan_flat'' ']);

dev1 = NSD_intan_flat('dev_intan',myExp);  

disp('Now will print all the channels :');

disp ( struct2table(getchannels(dev1)) );

disp ( getintervals(dev1) );

% disp(['Examining the amplifier channels versus time:']);

myClock = NSD_clock(dev1,1);

result1 = read_channel(dev1,'digitalin',1,myClock,0,Inf);

result2 = read_channel(dev1,'timestamp',1,myClock,0,Inf);

result1,

result2,

figure;
plot(result1.data);
box off;
ylabel('Digital value');
xlabel('Sample number');

channel = 'ai0';
sr = getsamplerate(dev1,1,'aux',channel),


