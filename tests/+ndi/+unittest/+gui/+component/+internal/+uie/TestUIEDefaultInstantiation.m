classdef TestUIEDefaultInstantiation < matlab.unittest.TestCase
    % TestUIEDefaultInstantiation Verifies that all concrete UI element classes
    % can be instantiated with their default constructors.

    methods (Test)

        function testCreateUIButton(testCase)
            obj = ndi.gui.component.internal.uie.UIButton();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIButton);
        end

        function testCreateUICheckbox(testCase)
            obj = ndi.gui.component.internal.uie.UICheckbox();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UICheckbox);
        end

        function testCreateUIContextMenu(testCase)
            obj = ndi.gui.component.internal.uie.UIContextMenu();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIContextMenu);
        end

        function testCreateUIDropdown(testCase)
            obj = ndi.gui.component.internal.uie.UIDropdown();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIDropdown);
        end

        function testCreateUIEditField(testCase)
            obj = ndi.gui.component.internal.uie.UIEditField();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIEditField);
        end

        function testCreateUIFigure(testCase)
            obj = ndi.gui.component.internal.uie.UIFigure();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIFigure);
        end

        function testCreateUIGridLayout(testCase)
            obj = ndi.gui.component.internal.uie.UIGridLayout();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIGridLayout);
        end

        function testCreateUILabel(testCase)
            obj = ndi.gui.component.internal.uie.UILabel();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UILabel);
        end

        function testCreateUIListbox(testCase)
            obj = ndi.gui.component.internal.uie.UIListbox();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIListbox);
        end

        function testCreateUIPanel(testCase)
            obj = ndi.gui.component.internal.uie.UIPanel();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UIPanel);
        end

        function testCreateUITab(testCase)
            obj = ndi.gui.component.internal.uie.UITab();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UITab);
        end

        function testCreateUITabGroup(testCase)
            obj = ndi.gui.component.internal.uie.UITabGroup();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UITabGroup);
        end

        function testCreateUITextArea(testCase)
            obj = ndi.gui.component.internal.uie.UITextArea();
            testCase.verifyClass(obj, ?ndi.gui.component.internal.uie.UITextArea);
        end

    end
end
