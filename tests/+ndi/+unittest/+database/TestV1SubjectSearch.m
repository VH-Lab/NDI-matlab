classdef TestV1SubjectSearch < matlab.unittest.TestCase
    % TestV1SubjectSearch - `isa subject` finds a v1 subject on a v1 database.
    %
    % ndi.query('', 'isa', 'subject') leaves out subjects of non-biological
    % types with '~exact_string' terms on subject.type.name. The v1 database
    % (didsqlite) searches in SQL, where such a term needs the field, so it
    % left out every v1 subject. didsqlite now searches with the plain
    % `isa subject` on a v1 database.

    properties
        session
        subjectID
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'v1subj');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('v1subj', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'mouse@vhlab');
            S.database_add(sub);
            testCase.session = S;
            testCase.subjectID = sub.id();
        end
    end

    methods (Test)
        function testIsaSubjectFindsAV1Subject(testCase)
            docs = testCase.session.database_search(ndi.query('', 'isa', 'subject'));
            testCase.verifyTrue(any(cellfun(@(d) strcmp(d.id(), testCase.subjectID), docs)));
        end

        function testIsaSubjectAndedWithAnotherTerm(testCase)
            q = ndi.query('', 'isa', 'subject') & ...
                ndi.query('base.session_id', 'exact_string', testCase.session.id());
            docs = testCase.session.database_search(q);
            testCase.verifyTrue(any(cellfun(@(d) strcmp(d.id(), testCase.subjectID), docs)));
        end

        function testIsaSubjectInsideAnOr(testCase)
            q = ndi.query('', 'isa', 'subject') | ndi.query('', 'isa', 'probe');
            docs = testCase.session.database_search(q);
            testCase.verifyTrue(any(cellfun(@(d) strcmp(d.id(), testCase.subjectID), docs)));
        end
    end
end
