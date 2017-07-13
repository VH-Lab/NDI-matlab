function test_intan_flat(dirname)
% TEST_NSD_VARIABLE - Test the functionality of the NSD_VARIABLE object
%
%  TEST_NSD_VARIABLE([DIRNAME])
%
%  Given a directory, this function tries to create some 
%  NSD_VARIABLE objects in the experiment. The test function
%  removes them on completion.
%
%  If DIRNAME is not provided, the default directory
%  [NSDPATH/example_experiments/exp1_eg] is used.
%
%

nsd_globals;

if nargin<1,
	mydirectory = [nsdpath filesep 'tools' filesep 'NSD' ...
                filesep 'example_experiments' ];
	dirname = [mydirectory filesep 'exp1_eg'];
end;

disp(['Creating a new experiment object in directory ' dirname '.']);
exp = nsd_experiment_dir('exp1',dirname);

disp(['Now we will add a variable of each allowed type...'])

disp(['First, we will add a variable branch (a collection of variables)...'])

myvardir = nsd_variable_branch(exp.variable,'Animal parameters');

disp(['Second, we will add a variable to the branch ...'])

myvar = nsd_variable('Animal age','double',30,'The age of the animal at the time of the experiment (days)','');

myvardir.add(myvar);

disp(['Third, we will add a variable file to the branch ...'])

myfilevar = nsd_variable_file(myvardir,'Things to write','Some things to write','no history');
 

  % store some data in the file
fname = myfilevar.filename();
fid = fopen(fname,'w','b'); % write big-endian
fwrite(fid,char([0:9]));
fclose(fid);


disp(['Now, we will access all of our saved variables:']);

disp(['First, the branch...'])
findmydir = load(exp.variable,'name','Animal parameters'),

disp(['Second, the variable...'])
findmyvar = load(findmydir,'name','Animal age')

disp(['Third, the file and its output (should be 0..9) ...'])
findmyfilevar = load(findmydir,'name','Things to write')

fname = findmyfilevar.filename();
fid = fopen(fname,'r','b');
a=double(fread(fid,Inf,'char'))
fclose(fid);

exp.variable_rm(myvardir);

