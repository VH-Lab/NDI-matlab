classdef TestUIECoreObjects < matlab.unittest.TestCase
    % TESTUIECOREOBJECTS Unit tests for the core NDI GUI Element classes.

    methods (Test)

        function testUILayout(testCase)
            % Test the UILayout class
            layout = ndi.gui.component.internal.uie.UILayout('Row', 1, 'Column', [2 3]);
            testCase.verifyEqual(layout.Row, 1);
            
            s = layout.toStruct();
            alphaS = layout.toAlphaNumericStruct();
            obj_alpha = ndi.gui.component.internal.uie.UILayout.fromAlphaNumericStruct(alphaS);
            testCase.verifyEqual(obj_alpha.Row, 1);
        end

        function testUIElement(testCase)
            % Test direct creation of the base UIElement class
            elem = ndi.gui.component.internal.uie.UIElement();
            elem.Tag = 'base-element';
            
            s = elem.toStruct();
            testCase.verifyEqual(s.Tag, 'base-element');
            
            alphaS = elem.toAlphaNumericStruct();
            obj_alpha = ndi.gui.component.internal.uie.UIElement.fromAlphaNumericStruct(alphaS);
            testCase.verifyEqual(obj_alpha.Tag, 'base-element');
        end

        function testUIVisualComponent(testCase)
            % Test the UIVisualComponent class
            vis = ndi.gui.component.internal.uie.UIVisualComponent();
            vis.ParentTag = 'MainPanel';
            testCase.verifyEqual(vis.ParentTag, 'MainPanel');

            alphaS = vis.toAlphaNumericStruct();
            obj_alpha = ndi.gui.component.internal.uie.UIVisualComponent.fromAlphaNumericStruct(alphaS);
            testCase.verifyEqual(obj_alpha.ParentTag, 'MainPanel');
        end

        function testUITextComponent(testCase)
            % Test the UITextComponent class
            textComp = ndi.gui.component.internal.uie.UITextComponent();
            textComp.FontWeight = 'bold';
            
            alphaS = textComp.toAlphaNumericStruct();
            obj_alpha = ndi.gui.component.internal.uie.UITextComponent.fromAlphaNumericStruct(alphaS);
            testCase.verifyEqual(obj_alpha.FontWeight, 'bold');
        end
        
        function testUIInteractiveComponent(testCase)
            % Test the UIInteractiveComponent class
            interact = ndi.gui.component.internal.uie.UIInteractiveComponent();
            interact.Tooltip = 'This is a test.';

            alphaS = interact.toAlphaNumericStruct();
            obj_alpha = ndi.gui.component.internal.uie.UIInteractiveComponent.fromAlphaNumericStruct(alphaS);
            testCase.verifyEqual(obj_alpha.Tooltip, 'This is a test.');
        end
        
    end
end