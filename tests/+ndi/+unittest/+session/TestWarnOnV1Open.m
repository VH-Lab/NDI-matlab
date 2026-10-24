classdef TestWarnOnV1Open < matlab.unittest.TestCase
%TESTWARNONV1OPEN Opening a session or dataset that holds v1 documents warns once.
%
%   Decided by Jess Haley, 2026-10-23 [warn on v1 open]: opening a dataset
%   that still holds unmigrated v1 documents warns once. Reading is
%   unchanged ([v1 read as stored]). VH-Lab/NDI-matlab#1055.
%
%   The warning is 'NDI:V2:v1DocumentsPresent'
%   (ndi.database.fun.warnIfV1Documents). A session or dataset created by
%   ndi.session.dir / ndi.dataset.dir is a v1 one (did-sqlite, v1 templates),
%   so creating one must not warn, and opening it again must, once.

    properties (Constant)
        Id = 'NDI:V2:v1DocumentsPresent'
    end

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)

        function testCreatingASessionDoesNotWarn(testCase)
            id = testCase.lastWarningIdOf(@() ndi.session.dir('ref_new', testCase.Root));
            testCase.verifyNotEqual(id, testCase.Id, ...
                'a new session holds nothing when it is opened, so there is nothing to warn about');
        end

        function testReopeningAV1SessionWarnsOnceWithTheCount(testCase)
            S = ndi.session.dir('ref_v1', testCase.Root);
            doc = ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '') + S.newdocument();
            S.database_add(doc);
            % every document of a did-sqlite (v1) database is a v1 document
            n = numel(S.database_search(ndi.query('', 'isa', 'base')));
            testCase.assertGreaterThanOrEqual(n, 2, 'the session document and the subject');

            testCase.verifyThat(@() ndi.session.dir('ref_v1', testCase.Root), ...
                matlab.unittest.constraints.IssuesWarnings({testCase.Id}, ...
                'RespectingCount', true), 'one warning per open');

            [id, msg] = testCase.lastWarningIdOf(@() ndi.session.dir('ref_v1', testCase.Root));
            testCase.verifyEqual(id, testCase.Id);
            testCase.verifySubstring(msg, sprintf('holds %d unmigrated v1 document', n));
            testCase.verifySubstring(msg, 'read as stored');
            testCase.verifySubstring(msg, 'ndi.migrate.local');
        end

        function testTheV1DocumentsAreStillReadAsStored(testCase)
            S = ndi.session.dir('ref_read', testCase.Root);
            doc = ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '') + S.newdocument();
            S.database_add(doc);
            warnState = warning('off', testCase.Id);
            testCase.addTeardown(@() warning(warnState));
            S2 = ndi.session.dir('ref_read', testCase.Root);
            got = S2.database_search(ndi.query('base.id', 'exact_string', doc.id(), ''));
            testCase.assertNumElements(got, 1);
            p = got{1}.document_properties;
            testCase.verifyEqual(p.subject.local_identifier, 'mouse@lab');
            testCase.verifyFalse(isfield(p.document_class, 'schema_version'), ...
                'a v1 document is not stamped or converted on read');
        end

        function testADatasetWarnsOnceNotOncePerSessionOpen(testCase)
            id = testCase.lastWarningIdOf(@() ndi.dataset.dir('ds_v1', testCase.Root));
            testCase.verifyNotEqual(id, testCase.Id, 'creating a dataset does not warn');

            % ndi.dataset.dir opens its folder as a session two or three
            % times on the way; the dataset still warns once
            testCase.verifyThat(@() ndi.dataset.dir(testCase.Root), ...
                matlab.unittest.constraints.IssuesWarnings({testCase.Id}, ...
                'RespectingCount', true));
            [id, msg] = testCase.lastWarningIdOf(@() ndi.dataset.dir(testCase.Root));
            testCase.verifyEqual(id, testCase.Id);
            testCase.verifySubstring(msg, 'The dataset at ');
        end

        function testTheWarningCanBeTurnedOff(testCase)
            ndi.session.dir('ref_off', testCase.Root);
            warnState = warning('off', testCase.Id);
            testCase.addTeardown(@() warning(warnState));
            id = testCase.lastWarningIdOf(@() ndi.session.dir('ref_off', testCase.Root));
            testCase.verifyNotEqual(id, testCase.Id);
        end
    end

    methods
        function [id, msg] = lastWarningIdOf(testCase, fn)
            % the last warning FN issues among this test's identifier only:
            % every other warning is off while FN runs (a warning that is off
            % does not update lastwarn), and the earlier state is restored
            allState = warning;
            restore = onCleanup(@() warning(allState));
            warning('off', 'all');
            % keep it off if the caller turned it off
            callerOff = any(strcmp({allState.identifier}, testCase.Id) & strcmp({allState.state}, 'off'));
            if ~callerOff
                warning('on', testCase.Id);
            end
            lastwarn('', '');
            fn();
            [msg, id] = lastwarn();
            clear restore
        end
    end
end
