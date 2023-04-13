function test_ndi_document(dirname)
% TEST_NDI_DOCUMENT - Test the functionality of the NDI_DOCUMENT object and the NDI_SESSION database
%
%  ndi.test.document([DIRNAME])
%
%  Given a directory, this function tries to create some 
%  NDI_VARIABLE objects in the session DATABASE. The test function
%  removes them on completion.
%
%  If DIRNAME is not provided, the default directory
%  [NDIEXAMPLEEXPERPATH/exp1_eg] is used.
%
%

ndi.globals;

test_struct = 0;

if nargin<1,
	dirname = [ndi_globals.path.exampleexperpath filesep 'exp1_eg'];
end;

disp(['Creating a new session object in directory ' dirname '.']);
E = ndi.session.dir('exp1',dirname);

 % if we ran the demo before, delete the entry

doc = E.database_search({'subject.id','vhlab12345'});
if ~isempty(doc),
	for i=1:numel(doc),
		E.database_rm(id(doc{i}));
	end;
end;

doc = E.newdocument('subjectmeasurement',...
	'base.name','Animal statistics',...
	'subject.id','vhlab12345', ...
	'subject.species','Mus musculus',...
	'subjectmeasurement.measurement','age',...
	'subjectmeasurement.value',30,...
	'subjectmeasurement.datestamp','2017-03-17T19:53:57.066Z'...
	);

 % add it here
E.database_add(doc);

  % store some data in the binary portion of the file
binarydoc = E.database_openbinarydoc(doc);
disp(['Storing ' mat2str(0:9) '...'])
binarydoc.fwrite(char([0:9]),'char');
binarydoc = E.database_closebinarydoc(binarydoc);

 % now read the object back

doc = E.database_search({'subject.id','vhlab12345'});
if numel(doc)~=1,
	error(['Found <1 or >1 document with subject.id vhlab12345; this means there is a database problem.']);
end;
doc = doc{1}, % should be only one match

  % test structure search form
doc = E.database_search(ndi.query('subject.id','exact_string','vhlab12345',''))
if numel(doc)~=1,
	error(['Found <1 or >1 document with subject.id vhlab12345; this means there is a database problem.']);
end;
doc = doc{1}, % should be only one match

doc = E.database_search(ndi.query('','isa','subjectmeasurement.json',''));
if numel(doc)~=1,
	error(['Found <1 or >1 document with subject.id vhlab12345; this means there is a database problem.']);
end;
doc = doc{1}, % should be only one match

 % read the binary data
binarydoc = E.database_openbinarydoc(doc);
disp('About to read stored data: ');
data = double(binarydoc.fread(10,'char'))',
binarydoc = E.database_closebinarydoc(binarydoc);

% remove the document

doc = E.database_search({'subject.id','vhlab12345'});
if ~isempty(doc),
	for i=1:numel(doc),
		E.database_rm(doc{i}.id());
	end;
end;


