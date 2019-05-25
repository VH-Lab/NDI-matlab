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

doc = E.database.search({'thing.name','mything'});
if ~isempty(doc),
	for i=1:numel(doc),
		E.database_rm(doc_unique_id(doc{i}));
	end;
end;

p = E.getprobes(); % should return 1 probe
[d,t] = readtimeseries(p{1}, 1, -Inf, Inf);
 % low-pass filter
[b,a]=cheby1(4,0.8,[0.1 300]/(0.5*1/median(diff(t))));
d_filter = filtfilt(b,a,d);

mything = ndi_thing_timeseries('mydirectthing','field', p{1}, 1);
doc = mything.newdocument();
E.database_add(doc);

[f] = openbinarydoc(E.database,doc),
vhsb_write(f,t,d_filter,'use_filelock',0);
E.database.closebinarydoc(f);

thethings = E.getthings();

thethings{1},


% remove the thing document

doc = E.database.search({'ndi_document.type','ndi_thing'});
if ~isempty(doc),
	for i=1:numel(doc),
		E.database_rm(doc_unique_id(doc{i}));
	end;
end;


