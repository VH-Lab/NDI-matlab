classdef sessionApp_test < matlab.unittest.TestCase
    % SESSIONAPP_TEST - Tests for ndi.gui.app.sessionApp discovery.
    %
    % These run headless (no GUI): they exercise the interface metadata,
    % the built-in app discovery, and the preference-driven package
    % extension used by the navigator Apps menu.

    properties
        OrigPackages string = ""
    end

    methods (TestMethodSetup)
        function saveAndClearPreference(testCase)
            % Snapshot and clear the user package list so each test starts
            % from a known state; restore it on teardown.
            try
                testCase.OrigPackages = ndi.preferences.get('GUI.Navigator.SessionAppPackages');
            catch
                testCase.OrigPackages = "";
            end
            testCase.addTeardown(@() ndi.preferences.set( ...
                'GUI.Navigator.SessionAppPackages', testCase.OrigPackages));
            ndi.preferences.set('GUI.Navigator.SessionAppPackages', "");
        end
    end

    methods (Test)
        function testInterfaceIsAbstractHandle(testCase)
            mc = meta.class.fromName('ndi.gui.app.sessionApp');
            testCase.verifyTrue(mc.Abstract);
            testCase.verifyTrue(any(strcmp({mc.SuperclassList.Name}, 'handle')));
        end

        function testListReturnsNameClassStruct(testCase)
            apps = ndi.gui.app.sessionApp.list();
            testCase.verifyClass(apps, 'struct');
            testCase.verifyTrue(all(isfield(apps, {'Name', 'Class'})));
        end

        function testBuiltinAppsDiscovered(testCase)
            apps    = ndi.gui.app.sessionApp.list();
            classes = string({apps.Class});
            testCase.verifyTrue(any(classes == "ndi.gui.app.pyraview"));
            testCase.verifyTrue(any(classes == "ndi.gui.app.spikeSorterImporter"));
        end

        function testDefaultPackagesIncludesBuiltins(testCase)
            pkgs = ndi.gui.app.sessionApp.defaultPackages();
            testCase.verifyTrue(any(pkgs == "ndi.gui.app"));
            testCase.verifyTrue(any(pkgs == "ndi.app"));
        end

        function testPreferenceExtendsPackages(testCase)
            % Names in the preference (';' or ',' separated) are added to the
            % scanned package set, whether or not they exist on the path.
            ndi.preferences.set('GUI.Navigator.SessionAppPackages', "mylab.apps; foo.bar");
            pkgs = ndi.gui.app.sessionApp.defaultPackages();
            testCase.verifyTrue(any(pkgs == "mylab.apps"));
            testCase.verifyTrue(any(pkgs == "foo.bar"));
            % Built-ins are still present.
            testCase.verifyTrue(any(pkgs == "ndi.gui.app"));
        end

        function testEmptyPreferenceIsBuiltinsOnly(testCase)
            pkgs = ndi.gui.app.sessionApp.defaultPackages();
            testCase.verifyEqual(sort(pkgs), sort(["ndi.gui.app", "ndi.app"]));
        end
    end
end
