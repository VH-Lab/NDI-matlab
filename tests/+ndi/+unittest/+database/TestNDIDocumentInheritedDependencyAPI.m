classdef TestNDIDocumentInheritedDependencyAPI < matlab.unittest.TestCase
    % The dependency methods ndi.document now inherits, and the two it keeps.
    %
    % Step 5 of VH-Lab/NDI-matlab#940. Three of the five dependency_* methods
    % were did.document's function with varargin and vlt.data.assign in place
    % of an arguments block, so they are inherited now. The other two are not
    % the same function and stay:
    %
    %   dependency_value_n   also falls back to an unnumbered dependency name
    %   set_dependency_value also requires depends_on to be non-empty, not
    %                        merely present
    %
    % That split is the thing worth pinning. The inherited add_ and remove_
    % call dependency_value_n and set_dependency_value with unqualified
    % function syntax, which dispatches on the first argument, so on an
    % ndi.document they still run NDI's versions. These tests exercise that
    % composition rather than either half alone.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
        end
    end

    methods
        function definingClass = definerOf(~, methodName)
            mc = meta.class.fromName('ndi.document');
            k = find(strcmp({mc.MethodList.Name}, methodName), 1);
            if isempty(k)
                definingClass = '';
            else
                definingClass = mc.MethodList(k).DefiningClass.Name;
            end
        end

        function doc = elementDoc(~)
            % 'element' declares two dependencies, underlying_element_id and
            % subject_id, so depends_on arrives as a non-empty struct array.
            doc = ndi.document('element');
        end

        function names = dependencyNames(~, doc)
            names = {doc.document_properties.depends_on.name};
        end
    end

    methods (Test)

        % ---- which class defines what ---------------------------------

        function testTheInheritedThreeComeFromDidDocument(testCase)
            testCase.verifyEqual(testCase.definerOf('dependency_value'), 'did.document');
            testCase.verifyEqual(testCase.definerOf('add_dependency_value_n'), 'did.document');
            testCase.verifyEqual(testCase.definerOf('remove_dependency_value_n'), 'did.document');
        end

        function testTheTwoWithExtraBehaviourStayWithNdiDocument(testCase)
            % Not housekeeping: inheriting either would lose behaviour, and a
            % later cleanup pass should have to notice that on purpose.
            testCase.verifyEqual(testCase.definerOf('dependency_value_n'), 'ndi.document');
            testCase.verifyEqual(testCase.definerOf('set_dependency_value'), 'ndi.document');
        end

        % ---- dependency_value ----------------------------------------

        function testDependencyValueReadsWhatWasSet(testCase)
            doc = testCase.elementDoc();
            doc = doc.set_dependency_value('subject_id', 'abc123');
            testCase.verifyEqual(doc.dependency_value('subject_id'), 'abc123');
        end

        function testDependencyValueErrorsForAnUnknownName(testCase)
            doc = testCase.elementDoc();
            testCase.verifyError(@() doc.dependency_value('no_such_id'), ?MException);
        end

        function testDependencyValueIsEmptyWhenToldNotToError(testCase)
            % Seven call sites across ndi.fun, ndi.gui and ndi.element rely on
            % this form, so the empty answer matters as much as the error.
            doc = testCase.elementDoc();
            testCase.verifyEmpty(doc.dependency_value('no_such_id', 'ErrorIfNotFound', 0));
        end

        function testDependencyValueAcceptsADoubleForALogicalOption(testCase)
            % did.document validates ErrorIfNotFound as (1,1) logical where
            % vlt.data.assign took anything. Every caller in the repo passes a
            % literal double, so the conversion has to work in both directions
            % -- 0 suppresses the error, 1 still raises it.
            doc = testCase.elementDoc();
            testCase.verifyEmpty(doc.dependency_value('no_such_id', 'ErrorIfNotFound', 0));
            testCase.verifyError( ...
                @() doc.dependency_value('no_such_id', 'ErrorIfNotFound', 1), ?MException);
        end

        % ---- add_dependency_value_n ----------------------------------

        function testAddDependencyValueNNumbersFromOne(testCase)
            doc = testCase.elementDoc();
            doc = doc.add_dependency_value_n('probe_id', 'first');
            testCase.verifyTrue(ismember('probe_id_1', testCase.dependencyNames(doc)));
            testCase.verifyEqual(doc.dependency_value('probe_id_1'), 'first');
        end

        function testAddDependencyValueNAppendsInOrder(testCase)
            doc = testCase.elementDoc();
            doc = doc.add_dependency_value_n('probe_id', 'first');
            doc = doc.add_dependency_value_n('probe_id', 'second');
            testCase.verifyEqual(doc.dependency_value('probe_id_1'), 'first');
            testCase.verifyEqual(doc.dependency_value('probe_id_2'), 'second');
        end

        function testAddDependencyValueNLeavesDeclaredOnesAlone(testCase)
            doc = testCase.elementDoc();
            before = testCase.dependencyNames(doc);
            doc = doc.add_dependency_value_n('probe_id', 'first');
            after = testCase.dependencyNames(doc);
            testCase.verifyTrue(all(ismember(before, after)), ...
                'adding a numbered dependency should not disturb the declared ones');
        end

        % ---- remove_dependency_value_n -------------------------------

        function testRemoveDependencyValueNRenumbersWhatFollows(testCase)
            % The part worth testing: removing _1 of three renames _2 and _3
            % down, so the list stays contiguous and the values travel with
            % their entries.
            doc = testCase.elementDoc();
            doc = doc.add_dependency_value_n('probe_id', 'first');
            doc = doc.add_dependency_value_n('probe_id', 'second');
            doc = doc.add_dependency_value_n('probe_id', 'third');

            doc = doc.remove_dependency_value_n('probe_id', '', 1);

            testCase.verifyEqual(doc.dependency_value('probe_id_1'), 'second');
            testCase.verifyEqual(doc.dependency_value('probe_id_2'), 'third');
            testCase.verifyFalse(ismember('probe_id_3', testCase.dependencyNames(doc)), ...
                'the list should be contiguous after a removal');
        end

        function testRemoveDependencyValueNErrorsPastTheEnd(testCase)
            doc = testCase.elementDoc();
            doc = doc.add_dependency_value_n('probe_id', 'first');
            testCase.verifyError(@() doc.remove_dependency_value_n('probe_id', '', 5), ...
                ?MException);
        end

        function testRemoveDependencyValueNStillErrorsWhenTheEntryIsMissing(testCase)
            % ErrorIfNotFound 0 suppresses the count check, but the "could not
            % locate entry" error after it is unguarded, so this still throws.
            % Worth pinning precisely because the option name suggests
            % otherwise.
            doc = testCase.elementDoc();
            doc = doc.add_dependency_value_n('probe_id', 'first');
            testCase.verifyError( ...
                @() doc.remove_dependency_value_n('probe_id', '', 5, 'ErrorIfNotFound', 0), ...
                ?MException);
        end

    end
end
