function test_ndi_dbleaf_branch(testing_memory)
% TEST_NDI_DBLEAF_BRANCH - Test and demonstrate use of NDI_DBLEAF and NDI_DBLEAF_BRANCH classes
%
%  TEST_NDS_DBLEAF_BRANCH(TESTING_MEMORY)
%
% Performs tests and demonstrations of the NDI_DBLEAF class and
% NDI_DBLEAF_BRANCH classes. If MEMORY is 1, then the test is done
% in memory. If TESTING_MEMORY is 0, then the test is done on disk
% at the directory [NDITESTPATH filesep 'test_ndi_dbleaf_branch_dir'].
%


if ~testing_memory,
	ndi_globals
	dirname = [nditestpath filesep 'test_ndi_dbleaf_branch_dir'];
	if ~exist(dirname),
		mkdir(dirname);
	else,
		rmdir(dirname,'s'); % clear this directory
		mkdir(dirname);
	end;
else,
	dirname = '';
end;

  % create an NDI_DBLEAF object

disp(['Creating NDI_DBLEAF...'])

l = ndi_dbleaf('test')

disp(['Creating an NDI_DBLEAF_BRANCH object...'])

t = ndi_dbleaf_branch(dirname,'testbranch',{'ndi_dbleaf'},0,testing_memory)

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

	t = ndi_pickdbleaf([dirname filesep d(1).name(1:ind(1)-1)]),
	t = ndi_dbleaf_branch([dirname filesep d(1).name(1:ind(1)-1)],'OpenFile'),

end;

disp(['Now will test adding a branch to a branch']);
t2 = ndi_dbleaf_branch(t,'testsubbranch',{'ndi_dbleaf'},0,testing_memory);

disp(['How many entries do we have now? ' int2str(t.numitems)])
disp(['What is our metadata?'])
t.metadata

disp(['Will now test adding multiple items..']);

l2 = ndi_dbleaf('test2');
l3 = ndi_dbleaf('test3');

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

