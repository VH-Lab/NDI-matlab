function test_ndi_thing(dirname)
% TEST_NDI_THING - Test the functionality of the NDI_THING object and the NDI_EXPERIMENT database
%
%  TEST_NDI_THING([DIRNAME])
%
%  Given a directory, this function tries to create some 
%  NDI_VARIABLE objects in the experiment DATABASE. The test function
%  removes them on completion.
%
%  If DIRNAME is not provided, the default directory
%  [NDIEXAMPLEEXPERPATH/exp1_eg_saved] is used.
%
%

ndi_globals;

test_struct = 0;

if nargin<1,
	dirname = [ndiexampleexperpath filesep 'exp1_eg_saved'];
end;

disp(['Creating a new experiment object in directory ' dirname '.']);
E = ndi_experiment_dir('exp1',dirname);

 % if we ran the demo before, delete the entry

doc = E.database_search({'ndi_document.type','ndi_thing(.*)'});
if ~isempty(doc),
	for i=1:numel(doc),
		E.database_rm(doc{i}.id());
	end;
end;

p = E.getprobes(); % should return 1 probe
[d,t] = readtimeseries(p{1}, 1, -Inf, Inf);
 % low-pass filter
[b,a]=cheby1(4,0.8,[300]/(0.5*1/median(diff(t))),'low');
d_filter = filtfilt(b,a,d);

mything1 = ndi_thing_timeseries(E,'mydirectthing',p{1}.reference,'field', p{1}, 1);

et = p{1}.epochtable;
mything2 = ndi_thing_timeseries(E,'myindirectthing',p{1}.reference,'lfp', p{1}, 0);
[mything2,mydoc]=mything2.addepoch(et(1).epoch_id,et(1).epoch_clock{1},et(1).t0_t1{1},t,d_filter); 

 % demo adding a thing that does not depend on an antecedent thing at all
mything3 = ndi_thing_timeseries(E,'mymadeupthing','madeup','madeup', [], 0);
[mything3,mydoc3] = mything3.addepoch('epoch1',ndi_clocktype('dev_local_time'),[0 10],[0:10]',[0:10]');

et_t1 = mything1.epochtable();
et_t2 = mything2.epochtable();
et_t3 = mything3.epochtable();

thing1 = E.getthings('thing.name','mydirectthing');
thing2 = E.getthings('thing.name','myindirectthing');
thing3 = E.getthings('thing.name','mymadeupthing');

[d1,t1] = readtimeseries(thing1{1},1,-Inf,Inf);
[d2,t2] = readtimeseries(thing2{1},1,-Inf,Inf); % filtered data

figure
plot(t1,d1);
hold on
plot(t2,d2,'g');
xlabel('Time (s)');
ylabel('Voltage (V)');
title(['Raw data is blue, filtered is green']);
box off;

[d3,t3] = readtimeseries(thing3{1},1,-Inf,Inf),

% remove the thing documents

doc = E.database_search({'ndi_document.type','ndi_thing(.*)'});
if ~isempty(doc),
	for i=1:numel(doc),
		E.database_rm(doc{i}.id());
	end;
end;

