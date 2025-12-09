classdef buildSession < matlab.unittest.TestCase
    properties
        Session
    end

    methods (TestMethodSetup)
        function buildSessionSetup(testCase)
            % BUILDSESSIONSETUP - Build an example Intan session in a temporary directory

            % Create a temporary directory
            dirname = tempname;
            mkdir(dirname);

            % Locate the source file
            source_dir = fullfile(ndi.common.PathConstants.ExampleDataFolder, 'exp1_eg_saved');
            filename = 'Intan_160317_125049_short.rhd';
            source_file = fullfile(source_dir, filename);

            % Copy the file
            copyfile(source_file, dirname);

            % Create the probe map file
            probemap_filename = fullfile(dirname, 'Intan_160317_125049_short.epochprobemap.ndi');
            if ~exist(probemap_filename,'file')
                fid = fopen(probemap_filename, 'wt');
                if fid<0
                    error(['Could not open ' probemap_filename ' for writing.']);
                end
                fprintf(fid,'name\treference\ttype\tdevicestring\tsubjectstring\n');
                fprintf(fid,'ctx\t1\tn-trode\tintan1:ai1\tanteater27@nosuchlab.org\n');
                fclose(fid);
            end

            % Create the session object
            testCase.Session = ndi.session.dir('exp1', dirname);

            % Remove every element from the session to start
            testCase.Session.database_clear('yes');

            % Remove any existing daqsystem
            dev = testCase.Session.daqsystem_load('name','(.*)');
            if ~isempty(dev) && ~iscell(dev)
                dev = {dev};
            end
            if iscell(dev)
                for i=1:numel(dev)
                    testCase.Session.daqsystem_rm(dev{i});
                end
            end
            testCase.Session.cache.clear();

            % Add acquisition daqsystem (intan)
            dt = ndi.file.navigator(testCase.Session, {'#.rhd', '#.epochprobemap.ndi'},'ndi.epoch.epochprobemap_daqsystem',{'(.*)epochprobemap.ndi'});
            dev1 = ndi.daq.system.mfdaq('intan1',dt,ndi.daq.reader.mfdaq.intan());
            testCase.Session.daqsystem_add(dev1);

            % Add subject
            subject = ndi.subject('anteater27@nosuchlab.org','');
            testCase.Session.database_add(subject.newdocument());

            % Add a document
            doc = testCase.Session.newdocument('subjectmeasurement',...
                'base.name','Animal statistics',...
                'subjectmeasurement.measurement','age',...
                'subjectmeasurement.value',30,...
                'subjectmeasurement.datestamp','2017-03-17T19:53:57.066Z'...
                );

            doc = doc.set_dependency_value('subject_id',subject.id());
            testCase.Session.database_add(doc);
        end
    end

    methods (TestMethodTeardown)
        function buildSessionTeardown(testCase)
            if ~isempty(testCase.Session)
                % Clean up temporary directory
                path = testCase.Session.path();
                if isfolder(path)
                    rmdir(path, 's');
                end
            end
        end
    end

    methods (Static)
        function session = withDocsAndFiles()
            % WITHDOCSANDFILES - Create a session with docs and files
            %
            % SESSION = WITHDOCSANDFILES()
            %
            % Creates an NDI.SESSION.DIR object in a temporary directory
            % with 5 NDI.DOCUMENTS of type 'demoNDI'.
            %
            % The documents have names 'doc_1', 'doc_2', ..., 'doc_5'.
            % The file content for each is 'doc_1', 'doc_2', etc.

            % Create a temporary directory
            dirname = tempname;
            mkdir(dirname);

            % Create the session object
            session = ndi.session.dir('exp_demo', dirname);

            % Create docs and files
            for i=1:5
                ndi.unittest.session.buildSession.addDocsWithFiles(session, i);
            end
        end

        function addDocsWithFiles(session, docNumber)
            % ADDDOCSWITHFILES - Add a document with files to the session
            %
            % ADDDOCSWITHFILES(SESSION, DOCNUMBER)
            %
            % Adds a document of type 'demoNDI' to the session.
            % The document has name 'doc_<DOCNUMBER>' and the file content is also 'doc_<DOCNUMBER>'.

            dirname = session.path();
            docname = sprintf('doc_%d', docNumber);
            filename = fullfile(dirname, docname);

            % Create file content
            fid = fopen(filename, 'w');
            fwrite(fid, docname, 'char');
            fclose(fid);

            % Create document
            % Create a blank document first to get the structure
            doc = ndi.document('demoNDI') + session.newdocument();

            % Modify properties
            doc_props = doc.document_properties;
            doc_props.base.name = docname;
            doc_props.demoNDI.value = docNumber;

            % Recreate document with modified properties
            doc = ndi.document(doc_props);

            % Add the file info
            doc = doc.add_file('filename1.ext', filename);

            % Add to session
            session.database_add(doc);
        end
    end
end
