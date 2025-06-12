classdef TestUIEStructSerialization < matlab.unittest.TestCase
    % TestUIEStructSerialization Verifies the serialization and deserialization
    % of UI element classes to and from structs and alphanumeric structs.

    methods (Test)

        function testUIButtonSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UIButton());
        end

        function testUICheckboxSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UICheckbox());
        end
        
        function testUIContextMenuSerialization(testCase)
            obj = ndi.gui.component.internal.uie.UIContextMenu();
            obj.Items = {'Item 1'; 'Item 2'};
            testCase.runSerializationTest(obj);
        end

        function testUIDropdownSerialization(testCase)
            obj = ndi.gui.component.internal.uie.UIDropdown();
            obj.Items = {'Option A'; 'Option B'};
            testCase.runSerializationTest(obj);
        end

        function testUIEditFieldSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UIEditField());
        end

        function testUIFigureSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UIFigure());
        end

        function testUIGridLayoutSerialization(testCase)
            obj = ndi.gui.component.internal.uie.UIGridLayout();
            obj.RowHeight = {'1x', '22', 'fit'};
            obj.ColumnWidth = {'2x', '100'};
            testCase.runSerializationTest(obj);
        end

        function testUILabelSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UILabel());
        end

        function testUIListboxSerialization(testCase)
            obj = ndi.gui.component.internal.uie.UIListbox();
            obj.Items = {'List Item 1'; 'List Item 2'; 'List Item 3'};
            testCase.runSerializationTest(obj);
        end

        function testUIPanelSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UIPanel());
        end

        function testUITabSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UITab());
        end
        
        function testUITabGroupSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UITabGroup());
        end

        function testUITextAreaSerialization(testCase)
            testCase.runSerializationTest(ndi.gui.component.internal.uie.UITextArea());
        end

    end

    methods (Access = private)
        function runSerializationTest(testCase, obj)
            % Helper function to run the standard serialization test procedure.
            
            % Get the fully qualified class name as a string
            className = string(class(obj));

            % --- Test toStruct and fromStruct ---
            S = obj.toStruct();
            objFromS = ndi.util.StructSerializable.fromStruct(className, S);
            testCase.verifyEqual(objFromS, obj, ...
                ['Object recreated from struct does not match original for class: ' className]);

            % --- Test toAlphaNumericStruct and fromAlphaNumericStruct ---
            alphaS = obj.toAlphaNumericStruct();
            objFromAlphaS = ndi.util.StructSerializable.fromAlphaNumericStruct(className, alphaS);
            testCase.verifyEqual(objFromAlphaS, obj, ...
                ['Object recreated from alphanumeric struct does not match original for class: ' className]);
        end
    end
end
