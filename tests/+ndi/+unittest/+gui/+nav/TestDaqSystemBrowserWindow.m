classdef TestDaqSystemBrowserWindow < ndi.unittest.session.buildSession
    % TESTDAQSYSTEMBROWSERWINDOW - ndi.gui.nav.daqSystemBrowser on a real session
    %
    % Opens the browser (hidden) on the example Intan session built by
    % ndi.unittest.session.buildSession, which has one DAQ system, 'intan1',
    % whose epochs are '#.rhd' + '#.epochprobemap.ndi' file pairs and whose
    % epoch probe map is the '(.*)epochprobemap.ndi' file. Exercises the
    % list, the detail panel, and loading and choosing epochs.

    properties
        Browser
    end

    methods (TestMethodSetup)
        function openBrowser(testCase)
            testCase.Browser = ndi.gui.nav.daqSystemBrowser(testCase.Session, ...
                'Visible', 'off');
            testCase.addTeardown(@() delete(testCase.Browser.Figure));
        end
    end

    methods (Test)
        function testListsDaqSystems(testCase)
            b = testCase.Browser;
            testCase.verifyNumElements(b.Info, 1);
            testCase.verifyEqual(b.Info(1).name, 'intan1');
            testCase.verifyEqual(b.List.Items, {'intan1'});
            testCase.verifyEqual(b.List.Value, 1);
        end

        function testDescribesNavigator(testCase)
            s = testCase.Browser.Info(1);
            testCase.verifyEqual(s.daqClass, 'ndi.daq.system.mfdaq');
            testCase.verifyEqual(s.readerClass, 'ndi.daq.reader.mfdaq.intan');
            testCase.verifyEqual(s.navigatorClass, 'ndi.file.navigator');
            testCase.verifyEqual(s.fileParameters, {'#.rhd', '#.epochprobemap.ndi'});
            testCase.verifyEqual(s.epochProbeMapClass, 'ndi.epoch.epochprobemap_daqsystem');
            testCase.verifyEqual(s.epochProbeMapFileParameters, {'(.*)epochprobemap.ndi'});
        end

        function testDetailPanelShowsPatterns(testCase)
            labels = findall(testCase.Browser.DetailGrid, 'Type', 'uilabel');
            texts = {labels.Text};
            testCase.verifyTrue(any(strcmp(texts, 'intan1')), 'title');
            testCase.verifyTrue(any(strcmp(texts, 'Files in each epoch')));
            testCase.verifyTrue(any(strcmp(texts, '#.rhd')));
            testCase.verifyTrue(any(strcmp(texts, '(.*)epochprobemap.ndi')));
            % class names are shortened, full name on hover
            intan = labels(strcmp(texts, 'intan'));
            testCase.verifyNumElements(intan, 1);
            testCase.verifyEqual(char(intan.Tooltip), 'ndi.daq.reader.mfdaq.intan');
        end

        function testEpochsNotLoadedUntilAsked(testCase)
            b = testCase.Browser;
            testCase.verifyEmpty(b.Epochs{1});
            testCase.verifyEqual(char(b.EpochDropdown.Enable), 'off');
        end

        function testLoadEpochsShowsFiles(testCase)
            b = testCase.Browser;
            b.loadEpochs(1);
            testCase.verifyNumElements(b.Epochs{1}, 1);
            testCase.verifyEqual(char(b.EpochDropdown.Enable), 'on');
            testCase.verifyEqual(b.EpochDropdown.Value, 1);
            testCase.verifyEqual(char(b.EpochButton.Enable), 'off');

            rows = b.EpochTable.Data;
            names = rows(:, 1);
            rhd = strcmp(names, 'Intan_160317_125049_short.rhd');
            pm  = strcmp(names, 'Intan_160317_125049_short.epochprobemap.ndi');
            testCase.verifyEqual(nnz(rhd), 1);
            testCase.verifyEqual(nnz(pm), 1);
            testCase.verifyEqual(rows{rhd, 2}, '#.rhd');
            testCase.verifyEqual(rows{pm, 3}, 'epoch probe map');
        end

        function testChooseEpochAndReselect(testCase)
            b = testCase.Browser;
            b.loadEpochs(1);
            b.chooseEpoch(1);
            testCase.verifyEqual(size(b.EpochTable.Data, 2), 3);
            % choosing a nonexistent epoch leaves the table alone
            before = b.EpochTable.Data;
            b.chooseEpoch(99);
            testCase.verifyEqual(b.EpochTable.Data, before);
            % reselecting the DAQ system rebuilds the panel and keeps the
            % already-loaded epochs
            b.select(1);
            testCase.verifyEqual(char(b.EpochDropdown.Enable), 'on');
            testCase.verifyEqual(b.EpochTable.Data, before);
        end
    end
end
