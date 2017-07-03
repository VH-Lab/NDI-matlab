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

disp(['Now we will add a variable of each allowed type...'])

disp(['First, we will add a variable branch (a collection of variables)...'])

myvardir = nsd_variable_branch(exp.variable,'Animal parameters');

disp(['Second, we will add a variable to the branch ...'])

myvar = nsd_variable('Animal age','double',30,'The age of the animal at the time of the experiment (days)','');

myvardir.add(myvar);

disp(['Third, we will add a variable file to the branch ...'])

myfilevar = nsd_variable_file(myvardir,'Things to write','Some things to write','no history');

disp(['Now, we will access all of our saved variables:']);

disp(['First, the branch...'])
findmydir = load(exp.variable,'name','Animal parameters'),

disp(['Second, the variable...'])
findmyvar = load(findmydir,'name','Animal age')

disp(['Third, the file ...'])
findmyfilevar = load(findmydir,'name','Things to write')

exp.variable_rm(myvardir);

