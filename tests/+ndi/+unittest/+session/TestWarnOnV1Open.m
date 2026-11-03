classdef TestWarnOnV1Open < matlab.unittest.TestCase
%TESTWARNONV1OPEN Opening a session or dataset that holds v1 documents warns once.
%
%   Decided by Jess Haley, 2026-10-23 [warn on v1 open]: opening a dataset
%   that still holds unmigrated v1 documents warns once. Reading is
%   unchanged ([v1 read as stored]). VH-Lab/NDI-matlab#1055.
%
%   The warning is 'NDI:V2:v1DocumentsPresent'
%   (ndi.database.fun.warnIfV1Documents). Creating a session or dataset
%   must not warn. On the V2 line a new session or dataset is a V2 one
%   ([V2 branch writes V2 only], Jess Haley, 2026-11-03), and a v1 database
%   is read-only ([v1 database read-only on the v2 line]), so the v1 folders
%   here are written by the fixture ndi.unittest.session.makeV1Session.

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
            testCase.verifyNoV1Warning(@() ndi.session.dir('ref_new', testCase.Root), ...
                'a new session holds nothing when it is opened, so there is nothing to warn about');
        end

        function testReopeningAV1SessionWarnsOnceWithTheCount(testCase)
            ndi.unittest.session.makeV1Session(testCase.Root, 'ref_v1', ...
                {ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '')});
            warnState = warning('off', testCase.Id);
            S = ndi.session.dir('ref_v1', testCase.Root);
            warning(warnState);
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
            [~, docs] = ndi.unittest.session.makeV1Session(testCase.Root, 'ref_read', ...
                {ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '')});
            doc = docs{2};
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
            newRoot = tempname;
            mkdir(newRoot);
            testCase.addTeardown(@() rmdir(newRoot, 's'));
            testCase.verifyNoV1Warning(@() ndi.dataset.dir('ds_new', newRoot), ...
                'creating a dataset does not warn (its session opens are silenced)');

            ndi.unittest.session.makeV1Session(testCase.Root, 'ds_v1', {}, ...
                'ObjectType', 'dataset');

            % ndi.dataset.dir opens its folder as a session two or three
            % times on the way; the dataset still warns once
            testCase.verifyThat(@() ndi.dataset.dir(testCase.Root), ...
                matlab.unittest.constraints.IssuesWarnings({testCase.Id}, ...
                'RespectingCount', true));
            [id, msg] = testCase.lastWarningIdOf(@() ndi.dataset.dir(testCase.Root));
            testCase.verifyEqual(id, testCase.Id);
            testCase.verifySubstring(msg, 'The dataset at ');
        end

        function testTurningTheWarningOffIsKept(testCase)
            % ndi.dataset.dir switches the warning off for its inner session
            % opens and restores it; a caller's 'off' must survive that, and
            % its 'on' too
            ndi.unittest.session.makeV1Session(testCase.Root, 'ds_off', {}, ...
                'ObjectType', 'dataset');
            warnState = warning('off', testCase.Id);
            testCase.addTeardown(@() warning(warnState));
            ndi.dataset.dir(testCase.Root);
            testCase.verifyEqual(getfield(warning('query', testCase.Id), 'state'), 'off');
            warning('on', testCase.Id);
            testCase.verifyWarning(@() ndi.dataset.dir(testCase.Root), testCase.Id);
            testCase.verifyEqual(getfield(warning('query', testCase.Id), 'state'), 'on');
        end
    end

    methods
        function verifyNoV1Warning(testCase, fn, diagnostic)
            % FN issues no enabled NDI:V2:v1DocumentsPresent. Every other
            % warning is off while FN runs, so only this one can be seen
            % (IssuesNoWarnings counts enabled warnings only, which is also
            % why a warning silenced inside ndi.dataset.dir is not seen).
            allState = warning;
            restore = onCleanup(@() warning(allState));
            warning('off', 'all');
            warning('on', testCase.Id);
            testCase.verifyThat(fn, matlab.unittest.constraints.IssuesNoWarnings, diagnostic);
            clear restore
        end

        function [id, msg] = lastWarningIdOf(testCase, fn)
            % the last warning FN issues, for its message: every other
            % warning is off while FN runs. (lastwarn is updated by a
            % disabled warning too, so this is only used where FN is
            % expected to warn last.)
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
