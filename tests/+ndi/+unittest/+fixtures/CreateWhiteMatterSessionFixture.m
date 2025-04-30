classdef CreateWhiteMatterSessionFixture < matlab.unittest.fixtures.Fixture
% Create an NDI session using the whitematter reader in a temporary
% directory

    properties (SetAccess = private)
        TempDir % Temporary directory
        Session % Temporary NDI session
    end

    methods
        function setup(fixture)
            
            % Create a temporary directory
            import matlab.unittest.fixtures.WorkingFolderFixture
            tempFolderFix = fixture.applyFixture(WorkingFolderFixture('WithSuffix','_WhiteMatter'));
            fixture.TempDir = tempFolderFix.Folder;

            % Start NDI session
            S = ndi.session.dir('temp',fixture.TempDir);

            % Add White Matter DAQ system to session
            wm_filenav = ndi.file.navigator(S, ...
                {'#.bin', '#.epochprobemap.txt'}, ...
                'ndi.epoch.epochprobemap_daqsystem','#.epochprobemap.txt');
            wm_rdr = ndi.daq.reader.mfdaq.ndr('whitematter');
            wm_system = ndi.daq.system.mfdaq('wm_daqsystem', wm_filenav, wm_rdr);
            if ~isempty(S.daqsystem_load)
                S.daqsystem_clear();
            end
            S.daqsystem_add(wm_system);

            fixture.Session = S;

            fixture.SetupDescription = tempFolderFix.SetupDescription;
            fixture.TeardownDescription = ['   Cleared white matter session from database.',...
                newline,'   Deleted the temporary folder "',fixture.TempDir,'".'];
        end

        function teardown(fixture)
            
            % Clear session from database
            fixture.Session.database_clear('yes');
            disp(fixture.TeardownDescription)
        end
    end
end