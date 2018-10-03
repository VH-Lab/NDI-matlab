function test_nsd_variable(dirname)
% TEST_NSD_VARIABLE - Test the functionality of the NSD_VARIABLE object and the NSD_EXPERIMENT database
%
%  TEST_NSD_VARIABLE([DIRNAME])
%
%  Given a directory, this function tries to create some 
%  NSD_VARIABLE objects in the experiment DATABASE. The test function
%  removes them on completion.
%
%  If DIRNAME is not provided, the default directory
%  [NSDPATH/example_experiments/exp1_eg] is used.
%
%

nsd_globals;

test_struct = 0;

if nargin<1,
	mydirectory = [nsdpath filesep 'tools' filesep 'NSD' ...
                filesep 'example_experiments' ];
	dirname = [mydirectory filesep 'exp1_eg'];
end;

disp(['Creating a new experiment object in directory ' dirname '.']);
exp = nsd_experiment_dir('exp1',dirname);

disp(['Now clearing out any old variables...']);

findmyvar = load(exp.database,'name','Animal parameters');
if ~isempty(findmyvar),
	exp.database_rm(findmyvar);
end

disp(['Now we will add a variable of each allowed type...'])

disp(['First, we will add a variable branch (a collection of variables)...'])

myvardir = nsd_variable_branch(exp.database,'Animal parameters');

disp(['Second, we will add a variable to the branch ...'])

myvar = nsd_variable(myvardir, 'Animal age','double','Animal age in days', 30, 'The age of the animal at the time of the experiment (days)','');

disp(['Third, we will add a variable file to the branch ...'])

myfilevar = nsd_variable(myvardir, 'Things to write','file', 'Test: Some things to write', ...
		[], 'Some things to write','no history');
	 
	  % store some data in the file
fname = myfilevar.filename();
fid = fopen(fname,'w','b'); % write big-endian
fwrite(fid,char([0:9]));
fclose(fid);

disp(['Fourth, we will add a structure variable to the branch'])

mystruct.a = 5;
mystruct.b = 3;
mystructvar = nsd_variable(myvardir, 'Structure to write', 'struct', 'Test: A test structure', ...
		mystruct, 'Some things to write', 'no history');

disp(['..........................']);
disp(['Now, we will access all of our saved variables:']);

disp(['First, the branch...'])
findmydir = load(exp.database,'name','Animal parameters'),

disp(['Second, the variable...'])
findmyvar = load(findmydir,'name','Animal age')

disp(['Third, the file and its output (should be 0..9) ...'])
findmyfilevar = load(findmydir,'name','Things to write')

fname = findmyfilevar.filename();
fid = fopen(fname,'r','b');
a=double(fread(fid,Inf,'char'));
a(:)'
fclose(fid);

disp(['Fourth, the structure (should be a==5, b==3):']);

findmystructvar = load(findmydir,'type','Test: A test structure');
findmystructvar.data

disp(['Fifth, now let''s update this variable to (a==3, b==3):']);

mydata = findmystructvar.data;
mydata.a = 3;
findmystructvar = updatedata(findmystructvar,mydata);

findmystructvar = load(findmydir,'type','Test: A test structure');
findmystructvar.data

exp.database_rm(myvardir);

