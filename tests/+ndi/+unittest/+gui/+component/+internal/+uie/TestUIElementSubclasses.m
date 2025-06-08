classdef TestUIElementSubclasses < matlab.unittest.TestCase
    % TESTUIELEMENTSUBCLASSES Unit tests for the core NDI GUI Element classes.
    % This test suite now uses the "smart dispatcher" fromAlphaNumericStruct method.
    
    methods (Test)

        function testUILabel(testCase)
            label = ndi.gui.component.internal.uie.UILabel();
            label.Tag = 'title-label';
            alphaS = label.toAlphaNumericStruct();
            
            % --- UNIFIED CALLING SYNTAX ---
            className = 'ndi.gui.component.internal.uie.UILabel';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            testCase.verifyEqual(reconstructedObj.Tag, 'title-label');
        end

        function testUIEditField(testCase)
            editField = ndi.gui.component.internal.uie.UIEditField();
            editField.Value = 'Initial Text';
            alphaS = editField.toAlphaNumericStruct();

            % --- UNIFIED CALLING SYNTAX ---
            className = 'ndi.gui.component.internal.uie.UIEditField';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);

            testCase.verifyEqual(reconstructedObj.Value, 'Initial Text');
        end
        
        function testUICheckbox(testCase)
            cb = ndi.gui.component.internal.uie.UICheckbox();
            cb.Text = 'Enable Feature';
            cb.Value = true;
            
            alphaS = cb.toAlphaNumericStruct();

            % --- UNIFIED CALLING SYNTAX ---
            className = 'ndi.gui.component.internal.uie.UICheckbox';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            testCase.verifyTrue(reconstructedObj.Value);
            testCase.verifyEqual(reconstructedObj.Text, 'Enable Feature');
        end

        function testUIListbox(testCase)
            % Verifies the UIListbox class, which has a custom override.
            lb = ndi.gui.component.internal.uie.UIListbox();
            lb.Items = {'Item A'; 'Item B'; 'Item C'};
            
            alphaS = lb.toAlphaNumericStruct();
            testCase.verifyEqual(alphaS.Items, 'Item A, Item B, Item C');
            
            % --- UNIFIED CALLING SYNTAX ---
            % The base class will detect the override in UIListbox and call it.
            className = 'ndi.gui.component.internal.uie.UIListbox';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            testCase.verifyEqual(reconstructedObj.Items, {'Item A'; 'Item B'; 'Item C'});
        end

        function testUIButton(testCase)
            button = ndi.gui.component.internal.uie.UIButton();
            button.Callback = 'goButtonPushed';
            alphaS = button.toAlphaNumericStruct();

            % --- UNIFIED CALLING SYNTAX ---
            className = 'ndi.gui.component.internal.uie.UIButton';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);

            testCase.verifyEqual(reconstructedObj.Callback, 'goButtonPushed');
        end

    end
end