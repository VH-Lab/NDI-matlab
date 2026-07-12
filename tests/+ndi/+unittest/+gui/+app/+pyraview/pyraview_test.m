classdef pyraview_test < matlab.unittest.TestCase
    % PYRAVIEW_TEST - Unit tests for ndi.gui.app.pyraview
    %
    % These tests check the class contract without opening the GUI (which
    % needs a display and a real session): the constructor requires a
    % session, the class adopts the ndi.gui.app.sessionApp interface with a
    % constant Name, and it is found by the session-app discovery.

    methods (Test)
        function testRequiresSession(testCase)
            % The constructor's first argument is a required ndi.session, so
            % calling it with no arguments errors before any window is made.
            testCase.verifyError(@() ndi.gui.app.pyraview(), 'MATLAB:minrhs');
        end

        function testIsSessionApp(testCase)
            % pyraview must derive from the session-app interface.
            mc = meta.class.fromName('ndi.gui.app.pyraview');
            supers = {mc.SuperclassList.Name};
            testCase.verifyTrue(any(strcmp(supers, 'ndi.gui.app.sessionApp')));
        end

        function testNameProperty(testCase)
            % The menu label comes from a constant Name property.
            mc  = meta.class.fromName('ndi.gui.app.pyraview');
            idx = find(strcmp({mc.PropertyList.Name}, 'Name'), 1);
            testCase.verifyNotEmpty(idx);
            testCase.verifyTrue(mc.PropertyList(idx).Constant);
            testCase.verifyEqual(string(mc.PropertyList(idx).DefaultValue), "pyraview");
        end

        function testDiscoverable(testCase)
            % The discovery used by the navigator should find pyraview.
            apps    = ndi.gui.app.sessionApp.list();
            classes = string({apps.Class});
            testCase.verifyTrue(any(classes == "ndi.gui.app.pyraview"));
        end
    end
end
