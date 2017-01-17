function test_intan_flat(dirname)

% this tests the intan with t00002 data sample
% the getdata, getintervals and covert still need to modified based on the
% implementataion of the intan technique

disp(['Opening a new example sampleAPI with dirname ''exp1''']);
myExp = sampleAPI_dir(dirname);

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize devices ''sAPI_intan_flat'' ']);

dev1 = sAPI_intan_flat('dev_intan',myExp);  % note to self, maybe name not needed

disp('Now will print all the channels :');

ch=getchannels(dev1);

for i=1:length(ch),
	disp(ch(i));
end;

disp(['Examining the amplifier channels versus time:']);
result = read_channels(dev1,ch(1:2), sampleAPI_clock(dev1, 1), -Inf, Inf);

figure;
plot(result(1).data,result(2).data) ;