classdef TestUIECoreObjects < matlab.unittest.TestCase
    % TESTUIECOREOBJECTS Unit tests for the core NDI GUI Element classes.

    methods (Test)

        function testMixinClasses(testCase)
            % This test verifies the individual mixin classes can be created
            % and serialized, but does not test for inherited properties.
            
            % Test UIVisualComponent
            vis = ndi.gui.component.internal.uie.UIVisualComponent();
            vis.Position = [1 1 1 1];
            alphaS_vis = vis.toAlphaNumericStruct();
            className_vis = 'ndi.gui.component.internal.uie.UIVisualComponent';
            recon_vis = ndi.util.StructSerializable.fromAlphaNumericStruct(className_vis, alphaS_vis);
            testCase.verifyEqual(recon_vis.Position, [1 1 1 1]);

            % Test UITextComponent
            textComp = ndi.gui.component.internal.uie.UITextComponent();
            textComp.FontAngle = 'italic';
            alphaS_text = textComp.toAlphaNumericStruct();
            className_text = 'ndi.gui.component.internal.uie.UITextComponent';
            recon_text = ndi.util.StructSerializable.fromAlphaNumericStruct(className_text, alphaS_text);
            testCase.verifyEqual(recon_text.FontAngle, 'italic');
        end

        function testUIButtonComposition(testCase)
            % This test verifies that UIButton correctly composes properties
            % from all its superclasses.
            
            button = ndi.gui.component.internal.uie.UIButton();
            
            % Set properties from each inherited class
            button.Tag = 'confirm-button';         % from UIElement
            button.Position = [10 20 100 30];    % from UIVisualComponent
            button.FontWeight = 'bold';            % from UITextComponent
            button.Icon = 'check.png';             % from UIIconComponent
            button.Enable = 'off';                 % from UIInteractiveComponent
            button.Callback = 'confirmAction';     % from UIButton itself
            
            % Test round-trip serialization
            alphaS = button.toAlphaNumericStruct();
            className = 'ndi.gui.component.internal.uie.UIButton';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);

            % Verify one property from each superclass was restored correctly
            testCase.verifyEqual(reconstructedObj.Tag, 'confirm-button');
            testCase.verifyEqual(reconstructedObj.Position, [10 20 100 30]);
            testCase.verifyEqual(reconstructedObj.FontWeight, 'bold');
            testCase.verifyEqual(reconstructedObj.Icon, 'check.png');
            testCase.verifyEqual(reconstructedObj.Enable, 'off');
            testCase.verifyEqual(reconstructedObj.Callback, 'confirmAction');
        end
        
    end
end