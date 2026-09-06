classdef TestNDIDocumentInheritedDependencyAPI < matlab.unittest.TestCase
    % The dependency methods ndi.document now inherits, and the two it keeps.
    %
    % Steps 5 and 6 of VH-Lab/NDI-matlab#940.
    %
    % Step 5 inherited dependency_value, add_dependency_value_n and
    % remove_dependency_value_n, which were did.document's functions with
    % varargin and vlt.data.assign in place of an arguments block. It kept
    % dependency_value_n and set_dependency_value, which carried behaviour
    % did.document did not have.
    %
    % Step 6 inherits those two as well, plus eq and setproperties, because
    % VH-Lab/DID-matlab#179 and #180 moved that behaviour upstream: eq now
    % routes through id() instead of reading a field no document has,
    % setproperties assigns with assignPropertyPath instead of eval,
    % dependency_value_n falls back to an unnumbered name, and all three
    % readers of depends_on guard an empty list.
    %
    % plus is the one still overridden, and not for its dependency merging --
    % did.document does B-wins now too. It is the merge in step 4:
    % did.document uses did.datastructures.structmerge and ndi.document uses
    % vlt.data.structmerge, and if those order the merged fieldnames
    % differently the stored JSON key order changes. Unverified, so kept.

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

        function testTheOtherTwoAreNowInheritedToo(testCase)
            % These two kept extra behaviour until did.document grew it in
            % VH-Lab/DID-matlab#180 -- the unnumbered-name fallback in
            % dependency_value_n, and set_dependency_value narrowing
            % hasdependencies to numel>=1 so it can create the list from an
            % empty depends_on. Both are upstream now, so both are inherited.
            testCase.verifyEqual(testCase.definerOf('dependency_value_n'), 'did.document');
            testCase.verifyEqual(testCase.definerOf('set_dependency_value'), 'did.document');
        end

        function testEqAndSetPropertiesAreInheritedAndPlusIsNot(testCase)
            % eq and setproperties came upstream with #179 and #180. plus did
            % not: did.document merges with did.datastructures.structmerge and
            % ndi.document with vlt.data.structmerge, and those may not order
            % the merged fieldnames the same way, which would change stored
            % JSON key order. Kept until that is checked.
            testCase.verifyEqual(testCase.definerOf('eq'), 'did.document');
            testCase.verifyEqual(testCase.definerOf('setproperties'), 'did.document');
            testCase.verifyEqual(testCase.definerOf('plus'), 'ndi.document');
        end

        function testEqStillComparesByBaseId(testCase)
            % did.document's eq routes through id(), where ndi.document's read
            % document_properties.base.id directly. Same answer, since the
            % inherited id() reads exactly that field -- but worth pinning,
            % because eq now follows id() and would follow an override of it.
            docA = testCase.elementDoc();
            docB = testCase.elementDoc();
            testCase.verifyTrue(docA == docA);
            testCase.verifyFalse(docA == docB);
            testCase.verifyEqual(docA.id(), docA.document_properties.base.id);
        end

        function testSetPropertiesStillAssignsANestedPath(testCase)
            doc = testCase.elementDoc();
            doc = doc.setproperties('element.name', 'a_name');
            testCase.verifyEqual(doc.document_properties.element.name, 'a_name');
        end

        function testSetPropertiesRejectsAPropertyNameThatIsNotOne(testCase)
            % The inherited version uses did.datastructures.assignPropertyPath,
            % which is ndi.util.assignPropertyPath under another name --
            % verified identical apart from namespace and error identifier. A
            % property name is a name, not a fragment of MATLAB to run.
            doc = testCase.elementDoc();
            testCase.verifyError( ...
                @() doc.setproperties('element.name); disp(''x''); %', 1), ?MException);
        end

        function testDependencyValueNFindsAnUnnumberedEntry(testCase)
            % The behaviour that used to justify NDI's override, now upstream.
            doc = testCase.elementDoc();
            doc = doc.set_dependency_value('subject_id', 'a_value');
            testCase.verifyEqual(doc.dependency_value_n('subject_id'), {'a_value'});
        end

        function testSetDependencyValueCreatesTheListWhenDependsOnIsEmpty(testCase)
            % The other one: an empty depends_on has no .name to index, so the
            % inherited version must fall through to creating the first entry
            % rather than throwing.
            props = testCase.elementDoc().document_properties;
            props.depends_on = [];
            doc = ndi.document(props);
            doc = doc.set_dependency_value('subject_id', 'a_value', 'ErrorIfNotFound', 0);
            testCase.verifyEqual(doc.dependency_value('subject_id'), 'a_value');
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
