classdef TestObjectLayer < matlab.unittest.TestCase
%TESTOBJECTLAYER The V2 object layer (ndi.entity, ndi.subject, ndi.statement
%and its children, ndi.data_type) over a written Haley session.
%
%   Writes TestHaleyRecordings' synthetic concentration_0001 with its
%   assertions, manipulations and calculations, opens it with
%   ndi.session.dir, and asks the questions through the objects that
%   TestHaleyWrite answers by reading documents. Also checks that the v1
%   behaviour of ndi.subject is unchanged (V2_Object_Layer.md, D5 and D6).

    properties
        Root
        Session
        Result
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);
            testCase.Result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations", "metadata", ...
                "assertions", "manipulations", "calculations"], 'Sessions', "concentration_0001", ...
                'OutputRoot', fullfile(testCase.Root, 'haley_V2'), 'Write', true, ...
                'Overwrite', true, 'ReadVideos', false);
            testCase.Session = ndi.session.dir(testCase.Result.sessions.path{1});
        end
    end

    methods (Test)
        function testSubjectIsAnEntity(testCase)
            w = testCase.subject('concentration_worm0121');
            testCase.verifyClass(w, 'ndi.subject');
            testCase.verifyTrue(isa(w, 'ndi.entity'));
            testCase.verifyEqual(w.id(), w.document_id(), 'the subject keeps its document''s id');
            testCase.verifyEqual(w.kind(), 'subject');
            testCase.verifyEqual(w.name(), 'concentration_worm0121');
            testCase.verifyEqual(w.local_identifier, 'concentration_worm0121', ...
                'no @ is required of a V2 subject read from a document (D6)');
            if ndi.setup.V2.schemaHasField('subject', 'type')
                testCase.verifyEqual(w.type(), 'organism');
                g = ndi.subject.find(testCase.Session, 'Type', 'group');
                testCase.verifyNumElements(g, 4, 'one cohort per assay plate');
            end
            e = ndi.entity.fromDocument(testCase.Session, w.document_id());
            testCase.verifyClass(e, 'ndi.subject', 'fromDocument returns the subclass');
        end

        function testRelations(testCase)
            w = testCase.subject('concentration_worm0121');
            g = w.memberOf();
            testCase.verifyNumElements(g, 1);
            testCase.verifyEqual(g{1}.local_identifier, 'concentration_assayPlate0012_worms');
            m = g{1}.members();
            names = sort(cellfun(@(x) x.local_identifier, m, 'UniformOutput', false));
            testCase.verifyEqual(names, {'concentration_worm0121', 'concentration_worm0122'});
            T = g{1}.relations('member_of', 'Direction', 'in');
            testCase.verifyEqual(height(T), 2);
            testCase.verifyEqual(unique(T.direction), "in");

            p = testCase.subject('concentration_assayPlate0012_patch0001');
            w = p.partOf();
            testCase.verifyNumElements(w, 1);
            testCase.verifyEqual(w{1}.local_identifier, 'concentration_assayPlate0012');
            parts = w{1}.parts();
            testCase.verifyEqual(cellfun(@(x) x.local_identifier, parts, 'UniformOutput', false), ...
                {'concentration_assayPlate0012_patch0001'});
        end

        function testAssertions(testCase)
            c = testCase.subject('concentration_assayPlate0012_worms');
            T = c.assertions();
            testCase.verifyEqual(T.node(T.variable == "species"), "NCBITaxon:6239");
            testCase.verifyEqual(T.value(T.variable == "strain"), "N2");
            a = c.statements('Class', 'assertion', 'Variable', 'strain');
            testCase.verifyNumElements(a, 1);
            testCase.verifyClass(a{1}, 'ndi.assertion');
            testCase.verifyEqual(a{1}.composite(), 'term');
            testCase.verifyEqual(a{1}.value().canonical(), "N2");
            testCase.verifyEqual(a{1}.subject().id(), c.id());
            x = testCase.subject('concentration_assayPlate0013').assertions();
            testCase.verifyEqual(x.value(x.variable == "inclusion in analysis"), "excluded");
        end

        function testCalculationValueFromItsBody(testCase)
            w = testCase.subject('concentration_worm0121');
            sp = w.statements('Class', 'velocity_calculation');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyClass(sp{1}, 'ndi.calculation');
            testCase.verifyTrue(isa(sp{1}, 'ndi.interaction'));
            v = sp{1}.value();
            testCase.verifyClass(v, 'ndi.data_type');
            testCase.verifyEqual(v.class_name, 'velocity');
            testCase.verifyEqual(double(v), 121e-6 * ones(5, 1), 'AbsTol', 1e-15, ...
                'm/s by video frame, decoded from the sampled body');
            ax = sp{1}.axes();
            testCase.verifyEqual(ax.variable(1), "video frame");
            testCase.verifyEqual(ax.n(1), 5);

            in = sp{1}.inputs();
            testCase.verifyNumElements(in, 1);
            testCase.verifyClass(in{1}, 'ndi.calculation');
            testCase.verifyEqual(in{1}.variable_name(), 'midpoint position');
            xy = double(in{1}.value());
            testCase.verifyEqual(reshape(xy, 5, 2), [(1:5)' + 12.1 - 0.5, 3.5 * ones(5, 1)], 'AbsTol', 1e-12);
            P = in{1}.method_parameters();
            testCase.verifyEqual(sort(P.variable)', ["gap filling", "longest gap filled"]);

            de = w.statements('Class', 'length_calculation');
            testCase.verifyNumElements(de, 1);
            testCase.verifyNumElements(de{1}.inputs(), 2, 'the positions and the lawn mask');
            testCase.verifyEqual(double(de{1}.value()), 2 * 1e-3 / 33 * ones(5, 1), 'AbsTol', 1e-15);
        end

        function testManipulations(testCase)
            plate = testCase.subject('concentration_assayPlate0012');
            pour = plate.statements('Class', 'manipulation', 'Variable', 'NGM agar');
            testCase.verifyNumElements(pour, 1);
            testCase.verifyClass(pour{1}, 'ndi.manipulation');
            v = pour{1}.value();
            testCase.verifyEqual(v.class_name, 'dose');
            testCase.verifyEqual(v.raw.volume.liters, 0.025, 'AbsTol', 1e-12);
            t = pour{1}.time();
            testCase.verifyNumElements(t, 1);
            testCase.verifyEqual(t.kind, 'relative', 'poured relative to the seeding');
            testCase.verifyNotEmpty(t.referent_id);
            % the formulation is reached when its document is in this session
            fid = ndi.v2.edgeIds(pour{1}.document_properties(), 'formulation_id');
            testCase.verifyEqual(fid, {testCase.Result.metadata.ids('ngm')});
            f = pour{1}.formulation();
            if isempty(ndi.v2.getDocument(testCase.Session, fid{1}))
                testCase.verifyEmpty(f, 'a dataset-level formulation is not found from a session');
            else
                testCase.verifyEqual(f.class_name, 'formulation');
            end

            tm = plate.statements('Class', 'temperature_manipulation');
            testCase.verifyNumElements(tm, 2);
            m = sort(cellfun(@(s) s.method_name(), tm, 'UniformOutput', false));
            testCase.verifyEqual(m, {'ambient exposure', 'refrigeration'});
            for i = 1:2
                v = tm{i}.value();
                testCase.verifyNotEmpty(v.unit());
                testCase.verifyEqual(double(v), double(v.raw.(v.unit())));
            end

            moves = ndi.statement.find(testCase.Session, 'Variable', 'location', 'Method', 'agar plug transfer');
            testCase.verifyNotEmpty(moves);
            testCase.verifyTrue(all(cellfun(@(s) isa(s, 'ndi.manipulation'), moves)));
            P = moves{1}.method_parameters();
            testCase.verifyTrue(any(P.variable == "cleaning step"));
        end

        function testInteractionIsAbstract(testCase)
            testCase.verifyTrue(meta.class.fromName('ndi.interaction').Abstract);
        end

        function testV1SubjectUnchanged(testCase)
            % D5, D6: making a v1 subject still requires the @, and works as before
            testCase.verifyError(@() ndi.subject('nolab', 'a subject'), ?MException);
            s = ndi.subject('anteater23@nosuchlab.org', 'a subject');
            testCase.verifyEqual(s.local_identifier, 'anteater23@nosuchlab.org');
            testCase.verifyEqual(s.description, 'a subject');
            testCase.verifyTrue(isa(s, 'ndi.entity'));
            testCase.verifyEmpty(s.statements(), 'a subject with no container has no statements');
            testCase.verifyEqual(s.type(), '');
            d = s.newdocument();
            testCase.verifyEqual(d.document_properties.subject.local_identifier, 'anteater23@nosuchlab.org');
        end
    end

    methods
        function s = subject(testCase, local)
            x = ndi.subject.find(testCase.Session, 'LocalIdentifier', local);
            testCase.assertNumElements(x, 1, local);
            s = x{1};
        end
    end
end
