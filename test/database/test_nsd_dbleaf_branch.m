function test_nsd_dbleaf_branch(testing_memory)
% TEST_NSD_DBLEAF_BRANCH - Test and demonstrate use of NSD_DBLEAF and NSD_DBLEAF_BRANCH classes
%
%  TEST_NDS_DBLEAF_BRANCH(TESTING_MEMORY)
%
% Performs tests and demonstrations of the NSD_DBLEAF class and
% NSD_DBLEAF_BRANCH classes. If MEMORY is 1, then the test is done
% in memory. If TESTING_MEMORY is 0, then the test is done on disk
% at the directory [NSDTESTPATH filesep 'test_nsd_dbleaf_branch_dir'].
%


if ~testing_memory,
	nsd_globals
	dirname = [nsdtestpath filesep 'test_nsd_dbleaf_branch_dir'];
	if ~exist(dirname),
		mkdir(dirname);
	else,
		rmdir(dirname,'s'); % clear this directory
		mkdir(dirname);
	end;
else,
	dirname = '';
end;

  % create an NSD_DBLEAF object

disp(['Creating NSD_DBLEAF...'])

l = nsd_dbleaf('test')

disp(['Creating an NSD_DBLEAF_BRANCH object...'])

t = nsd_dbleaf_branch(dirname,'testbranch',{'nsd_dbleaf'},0,testing_memory)

disp(['Adding our leaf to the branch...'])

t=t.add(l);

disp(['How many entries do we have now? ' int2str(t.numitems)])
disp(['What is our metadata?'])
t.metadata

disp(['Now remove it...'])

t=t.remove(l.objectfilename);
disp(['How many entries do we have now? ' int2str(t.numitems)])
disp(['What is our metadata?'])
t.metadata

disp(['Now add it back...'])

t=t.add(l);

disp(['How many entries do we have now? ' int2str(t.numitems)])
disp(['What is our metadata?'])
t.metadata


disp(['Now will test searching and loading...']);
l = t.load('name','test')


if ~testing_memory,

	disp(['Now will test reading branch from disk']);
	d = dir([dirname filesep '*object_*.dbleaf_branch*']);
	ind=strfind(d(1).name,'.metadata');

	t = nsd_pickdbleaf([dirname filesep d(1).name(1:ind(1)-1)]),
	t = nsd_dbleaf_branch([dirname filesep d(1).name(1:ind(1)-1)],'OpenFile'),

end;

disp(['Now will test adding a branch to a branch']);
t2 = nsd_dbleaf_branch(t,'testsubbranch',{'nsd_dbleaf'},0,testing_memory);

disp(['How many entries do we have now? ' int2str(t.numitems)])
disp(['What is our metadata?'])
t.metadata

disp(['Will now test adding multiple items..']);

l2 = nsd_dbleaf('test2');
l3 = nsd_dbleaf('test3');

t,

t=t.add(l2);
t=t.add(l3);
disp(['How many entries do we have now? ' int2str(t.numitems)])
disp(['What is our metadata?'])
t.metadata

disp(['Will now test adding to branches of branches..'])
t2=t2.add(l)
t2=t2.add(l2)
t2=t2.add(l3)


disp(['Original branch: How many entries do we have now? ' int2str(t.numitems)])
disp(['What is our metadata?'])
t.metadata

disp(['branch of branch: How many entries do we have now? ' int2str(t2.numitems)])
disp(['What is our metadata?'])
t2.metadata

t.deleteobjectfile()

