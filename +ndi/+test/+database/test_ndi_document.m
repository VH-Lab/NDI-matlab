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

    test_struct = 0;

    if nargin<1,
        dirname = [ndi.common.PathConstants.ExampleDataFolder filesep 'exp1_eg'];
    end;

    disp(['Creating a new session object in directory ' dirname '.']);
    E = ndi.session.dir('exp1',dirname);

    % if we ran the demo before, delete the entry

    doc = E.database_search(ndi.query('','isa','demoNDI',''));
    if ~isempty(doc),
        for i=1:numel(doc),
            E.database_rm(id(doc{i}));
        end;
    end;

    doc = E.newdocument('demoNDI',...
        'base.name','Demo document',...
        'demoNDI.value', 5);

    % add a binary file

    binary_filename = [dirname filesep 'myfile.bin'];
    myfid = fopen(binary_filename,'w','ieee-le');
    if myfid>0,
    else,
        error(['unable to open file: ' binary_filename '.']);
    end;

    disp(['Storing ' mat2str(0:9) '...'])
    fwrite(myfid,char([0:9]),'char');
    fclose(myfid);

    doc = doc.add_file('filename1.ext',binary_filename);

    % add it here
    E.database_add(doc);

    % now read the object back

    doc = E.database_search(ndi.query('demoNDI.value','exact_number',5,''));
    if numel(doc)~=1,
        error(['Found <1 or >1 document with demoNDI.value of 5; this means there is a database problem.']);
    end;
    doc = doc{1}, % should be only one match

    doc = E.database_search(ndi.query('','isa','demoNDI',''));
    if numel(doc)~=1,
        error(['Found <1 or >1 document of type demoNDI; this means there is a database problem.']);
    end;
    doc = doc{1}, % should be only one match

    % read the binary data
    binarydoc = E.database_openbinarydoc(doc,'filename1.ext');
    disp('About to read stored data: ');
    data = double(binarydoc.fread(10,'char'))',
    binarydoc = E.database_closebinarydoc(binarydoc);

    if ~vlt.data.eqlen(0:9,data),
        error(['Data does not match.']);
    end;

    % remove the document

    doc = E.database_search(ndi.query('','isa','demoNDI',''));
    if ~isempty(doc),
        for i=1:numel(doc),
            E.database_rm(doc{i}.id());
        end;
    end;


