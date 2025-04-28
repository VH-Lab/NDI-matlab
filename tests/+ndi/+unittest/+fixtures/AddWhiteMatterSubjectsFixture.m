classdef AddWhiteMatterSubjectsFixture < matlab.unittest.fixtures.Fixture

    properties (SetAccess = private)
        Session % Temporary NDI session
        NumSubjects double % Number of subjects
        Subjects cell % Cell array of subject names
    end

    methods
        function fixture = AddWhiteMatterSubjectsFixture(Session,NumSubjects)
            fixture.Session = Session;
            fixture.NumSubjects = NumSubjects;
        end

        function setup(fixture)

            % Add subjects to database
            fixture.Subjects = cell(fixture.NumSubjects,1);
            for s = 1:fixture.NumSubjects
                fixture.Subjects{s} = sprintf('subject%i@whitematter',s);
                mysub = ndi.subject(fixture.Subjects{s},'white matter test subject');
                mysubdoc = mysub.newdocument + fixture.Session.newdocument();
                fixture.Session.database_add(mysubdoc);
            end
        end

        function teardown(fixture)
            mysub = fixture.Session.database_search(ndi.query('',...
                    'isa','subject'));
            for s = 1:numel(mysub)
                fixture.Session.database_rm(mysub(s));
            end
        end
    end

    methods (Access=protected)
        function tf = isCompatible(fixture1,fixture2)
            tf = fixture1.Format == fixture2.Format;
        end
    end
end