% ndi.session.mock - a mock session class for testing

classdef mock < ndi.session.dir

    methods
        function ndi_session_mock_obj = mock()
            % ndi.session.mock - Create a new ndi.session.mock object
            %
            % S = ndi.session.mock();
            %
            % Creates an ndi.session.mock object with the following:
            % a) a temporary path,
            % b) a fake subject ('anteater27@nosuchlab.org'),
            % c) a device 'fakedevice', and
            % d) a single epoch.
            %

            ref = 'mock_test';
            dirname = [ndi.common.PathConstants.TempFolder filesep 'mock_test'];

            if vlt.file.isfolder(dirname)
                rmdir(dirname,'s');
            end;
            mkdir(dirname);

            ndi_session_mock_obj = ndi_session_mock_obj@ndi.session.dir(ref,dirname);

            % make sure the mock data files are installed

            ndi_session_mock_obj.database_clear('yes');
            ndi_session_mock_obj.daqsystem_clear();

            fpath = [ndi.common.PathConstants.CommonFolder filesep 'example_sessions' filesep 'exp1_eg_saved'];

            fnames{1} = '.Intan_160317_125049_short.48a19d04440fdc9fdfc43074e7c33a77.epochid.ndi';
            fnames{2} = '.Intan_160317_125049_short.48a19d04440fdc9fdfc43074e7c33a77.epochprobemap.ndi';
            fnames{3} = 'Intan_160317_125049_short.rhd';

            for i=1:numel(fnames)
                if ~vlt.file.isfile([dirname filesep fnames{i}])
                    copyfile([fpath filesep fnames{i}],[dirname filesep fnames{i}]);
                    if i==2
                        mytable = vlt.file.loadStructArray([dirname filesep fnames{i}]);
                        mytable.devicestring = 'testdevice:ai1';
                        vlt.file.saveStructArray([dirname filesep fnames{i}],mytable);
                    end;
                end;
            end;

            % make sure the mock daqdevice is present

            d = ndi_session_mock_obj.daqsystem_load('name','testdevice');
            if isempty(d)
                dt = ndi.file.navigator(ndi_session_mock_obj, '.*\.rhd\>');  % look for .rhd files
                dev1 = ndi.daq.system.mfdaq('testdevice',dt,ndi.daq.reader.mfdaq.intan());
                ndi_session_mock_obj.daqsystem_add(dev1);
            end;

            a = ndi_session_mock_obj.database_search(ndi.query('subject','exact_string','anteater27@nosuchlab.org',''));
            if isempty(a)
                subject = ndi.subject('anteater27@nosuchlab.org','');
                ndi_session_mock_obj.database_add(subject.newdocument());
            end;
        end; % (ndi.session.mock)
    end; % methods()
end
