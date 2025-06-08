classdef TestUIElementSubclasses < matlab.unittest.TestCase
    % TESTUIELEMENTSUBCLASSES Unit tests for concrete subclasses of UIElement.
    
    methods (Test)

        function testUILabel(testCase)
            label = ndi.gui.component.internal.uie.UILabel();
            label.Tag = 'title-label';
            alphaS = label.toAlphaNumericStruct();
            
            className = 'ndi.gui.component.internal.uie.UILabel';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            testCase.verifyEqual(reconstructedObj.Tag, 'title-label');
        end

        function testUIEditField(testCase)
            editField = ndi.gui.component.internal.uie.UIEditField();
            editField.Value = 'Initial Text';
            alphaS = editField.toAlphaNumericStruct();

            className = 'ndi.gui.component.internal.uie.UIEditField';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);

            testCase.verifyEqual(reconstructedObj.Value, 'Initial Text');
        end
        
        function testUICheckbox(testCase)
            cb = ndi.gui.component.internal.uie.UICheckbox();
            cb.Text = 'Enable Feature';
            cb.Value = true;
            
            alphaS = cb.toAlphaNumericStruct();

            className = 'ndi.gui.component.internal.uie.UICheckbox';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            testCase.verifyTrue(reconstructedObj.Value);
            testCase.verifyEqual(reconstructedObj.Text, 'Enable Feature');
        end

        function testUIListbox(testCase)
            lb = ndi.gui.component.internal.uie.UIListbox();
            lb.Items = {'Item A'; 'Item B'; 'Item C'};
            
            alphaS = lb.toAlphaNumericStruct();
            testCase.verifyEqual(alphaS.Items, 'Item A, Item B, Item C');
            
            className = 'ndi.gui.component.internal.uie.UIListbox';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            testCase.verifyEqual(reconstructedObj.Items, {'Item A'; 'Item B'; 'Item C'});
        end

        function testUIButton(testCase)
            button = ndi.gui.component.internal.uie.UIButton();
            button.Callback = 'goButtonPushed';
            alphaS = button.toAlphaNumericStruct();

            className = 'ndi.gui.component.internal.uie.UIButton';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);

            testCase.verifyEqual(reconstructedObj.Callback, 'goButtonPushed');
        end

        % --- NEW TESTS ---

        function testUIDropdown(testCase)
            % Verifies the UIDropdown class and its custom deserialization.
            
            dd = ndi.gui.component.internal.uie.UIDropdown();
            dd.Tag = 'selection-dropdown';
            dd.Items = {'Option 1'; 'Option 2'};
            dd.Editable = 'on';
            
            % Perform serialization round-trip
            alphaS = dd.toAlphaNumericStruct();
            testCase.verifyEqual(alphaS.Items, 'Option 1, Option 2');
            
            % Use the base class dispatcher, which should call the override
            className = 'ndi.gui.component.internal.uie.UIDropdown';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            % Verify properties
            testCase.verifyEqual(reconstructedObj.Tag, 'selection-dropdown');
            testCase.verifyEqual(reconstructedObj.Items, {'Option 1'; 'Option 2'});
            testCase.verifyEqual(reconstructedObj.Editable, 'on');
        end

        function testUIContextMenu(testCase)
            % Verifies the UIContextMenu class and its custom deserialization.
            
            cm = ndi.gui.component.internal.uie.UIContextMenu();
            cm.Tag = 'file-context-menu';
            cm.Items = {'Open'; 'Rename'; 'Delete'};
            cm.Callbacks = {'open_cb'; 'rename_cb'; 'delete_cb'};
            
            % Perform serialization round-trip
            alphaS = cm.toAlphaNumericStruct();
            testCase.verifyEqual(alphaS.Items, 'Open, Rename, Delete');
            testCase.verifyEqual(alphaS.Callbacks, 'open_cb, rename_cb, delete_cb');

            % Use the base class dispatcher
            className = 'ndi.gui.component.internal.uie.UIContextMenu';
            reconstructedObj = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            
            % Verify properties
            testCase.verifyEqual(reconstructedObj.Tag, 'file-context-menu');
            testCase.verifyEqual(reconstructedObj.Items, {'Open'; 'Rename'; 'Delete'});
            testCase.verifyEqual(reconstructedObj.Callbacks, {'open_cb'; 'rename_cb'; 'delete_cb'});
        end

    end
end