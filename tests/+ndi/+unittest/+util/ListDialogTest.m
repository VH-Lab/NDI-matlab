classdef ListDialogTest < matlab.unittest.TestCase
% ListDialogTest - Unit tests for ndi.util.ListDialog.
%
%   Run with: results = runtests('ListDialogTest');
%
%   The dialog is exercised without blocking: each test builds it with
%   'Visible','off' and drives the OK/Cancel/close callbacks programmatically
%   (the same approach as TestProgressBarWindow), so getSelection (which
%   waits on uiwait) is never called here.

    methods (TestClassSetup)
        function closePreexisting(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiUtilListDialog'));
        end
    end

    methods (TestMethodTeardown)
        function closeAllDialogs(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiUtilListDialog'));
        end
    end

    methods (Test)
        function defaultFontSizeIs14(testCase)
            d = ndi.util.ListDialog({'a', 'b', 'c'}, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            testCase.verifyEqual(d.ListBox.FontSize, 14, ...
                'Default list font size should be 14 pt.');
        end

        function customFontSizeIsRespected(testCase)
            d = ndi.util.ListDialog({'a', 'b'}, 'Visible', 'off', 'FontSize', 18);
            testCase.addTeardown(@delete, d.Figure);
            testCase.verifyEqual(d.ListBox.FontSize, 18, ...
                'Custom list font size should be honoured.');
        end

        function itemsPopulatedAndFirstSelected(testCase)
            items = {'alpha', 'beta', 'gamma'};
            d = ndi.util.ListDialog(items, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            testCase.verifyEqual(d.ListBox.Items, items, 'Items not populated.');
            testCase.verifyEqual(d.ListBox.Value, 'alpha', ...
                'First item should be selected by default.');
        end

        function titleAndPromptApplied(testCase)
            d = ndi.util.ListDialog({'x'}, 'Visible', 'off', ...
                'Title', 'My Title', 'Prompt', 'Choose wisely:');
            testCase.addTeardown(@delete, d.Figure);
            testCase.verifyEqual(d.Figure.Name, 'My Title', 'Window title not applied.');
        end

        function confirmReturnsSelectedIndex(testCase)
            items = {'alpha', 'beta', 'gamma'};
            d = ndi.util.ListDialog(items, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            d.ListBox.Value = 'gamma';               % pick the third item
            fireButton(d.OKButton);
            testCase.verifyTrue(d.Confirmed, 'OK should mark the dialog confirmed.');
            testCase.verifyEqual(d.SelectedIndex, 3, 'Wrong index returned for OK.');
        end

        function confirmWithDefaultSelectionReturnsFirst(testCase)
            d = ndi.util.ListDialog({'one', 'two'}, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            fireButton(d.OKButton);                  % accept the default selection
            testCase.verifyTrue(d.Confirmed);
            testCase.verifyEqual(d.SelectedIndex, 1);
        end

        function cancelReturnsEmptyNotConfirmed(testCase)
            d = ndi.util.ListDialog({'a', 'b'}, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            d.ListBox.Value = 'b';
            fireButton(d.CancelButton);
            testCase.verifyFalse(d.Confirmed, 'Cancel must not confirm.');
            testCase.verifyEmpty(d.SelectedIndex, 'Cancel must clear the selection.');
        end

        function closingWindowCancels(testCase)
            d = ndi.util.ListDialog({'a', 'b'}, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            % Fire the close-request callback (as clicking the X would).
            d.Figure.CloseRequestFcn(d.Figure, []);
            testCase.verifyFalse(d.Confirmed, 'Closing the window must not confirm.');
            testCase.verifyEmpty(d.SelectedIndex);
        end

        function multiselectReturnsAllIndices(testCase)
            items = {'a', 'b', 'c', 'd'};
            d = ndi.util.ListDialog(items, 'Visible', 'off', 'Multiselect', true);
            testCase.addTeardown(@delete, d.Figure);
            d.ListBox.Value = items([1 3]);          % select 'a' and 'c'
            fireButton(d.OKButton);
            testCase.verifyTrue(d.Confirmed);
            testCase.verifyEqual(d.SelectedIndex, [1 3], ...
                'Multiselect should return all chosen indices, sorted.');
        end

        function emptyItemsDoNotError(testCase)
            d = ndi.util.ListDialog({}, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            testCase.verifyEmpty(d.ListBox.Items, 'Empty item list should stay empty.');
            fireButton(d.OKButton);                  % OK with nothing to select
            testCase.verifyFalse(d.Confirmed, 'Empty selection cannot be confirmed.');
            testCase.verifyEmpty(d.SelectedIndex);
        end

        function columnItemsAreNormalizedToRow(testCase)
            d = ndi.util.ListDialog({'a'; 'b'; 'c'}, 'Visible', 'off');
            testCase.addTeardown(@delete, d.Figure);
            testCase.verifyEqual(size(d.Items), [1 3], ...
                'A column cell of items should be normalised to a row.');
        end

        function constructionDoesNotBlock(testCase)
            % Building the dialog must return immediately (no uiwait), so a
            % plain construct/inspect/destroy cycle completes on its own.
            d = ndi.util.ListDialog({'a', 'b'}, 'Visible', 'off');
            testCase.verifyClass(d.Figure, 'matlab.ui.Figure');
            delete(d.Figure);
            testCase.verifyFalse(isvalid(d.Figure));
        end
    end
end

function fireButton(btn)
%FIREBUTTON Invoke a uibutton's ButtonPushedFcn as a click would.
    btn.ButtonPushedFcn(btn, []);
end
