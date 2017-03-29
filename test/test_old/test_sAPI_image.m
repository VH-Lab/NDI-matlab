function test_NSD_image(dirname)

%% this function works as a sample test function specifically for the 
%% NSD_image device (tiffstack)


disp(['Opening a new example NSD with dirname ''exp2''']);
myExp = NSD_dir(dirname);

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize devices ''dev_tiffstack'' ']);

dev1 = NSD_image_tiffstack('dev_tiffstack',myExp);  

disp('Now will print all the channels :');

disp ( struct2table(getchannels(dev1)) );

disp ( getintervals(dev1) );

% disp(['Examining the amplifier channels versus time:']);

<<<<<<< HEAD:test/test_old/test_sAPI_image.m
myClock = sampleAPI_clock(dev1,1);
=======
myClock = NSD_clock(dev1,1);
>>>>>>> 94360047df90390c706266a3ab801ce24431d8b6:test/test_old/test_sAPI_image.m

result1 = read_channel(dev1,'digitalin',1,myClock,0,50);

result2 = read_channel(dev1,'timestamp',1,myClock,0,Inf);

% result1,
% 
% result2,
% 
% figure;
% plot(result1.data);
% box off;
% ylabel('Digital value');
% xlabel('Sample number');
% 
% channel = 'ai0';
% sr = getsamplerate(dev1,1,'aux',channel),

