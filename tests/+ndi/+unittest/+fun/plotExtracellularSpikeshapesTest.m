classdef plotExtracellularSpikeshapesTest < matlab.unittest.TestCase
    % PLOTEXTRACELLULARSPIKESHAPESTEST - tests for ndi.fun.plot_extracellular_spikeshapes
    %
    %   The function takes its documents as the third argument, so these tests
    %   supply plain structs with the fields it reads and need no session or
    %   database. Graphics land on the figure the function creates, which the
    %   teardown closes.
    %
    %   testSharedXLimitsSpanEveryDocument is the reason this file exists: the
    %   shared x-limits were accumulated as
    %
    %       x_axis(2) = max(x_axis(1), max(...));
    %
    %   reading index 1 -- the running MINIMUM -- where index 2 was meant, so
    %   the upper limit tracked the minimum instead of accumulating. Nothing
    %   tested it, which is why it survived.

    methods (TestMethodTeardown)
        function closeFigures(~)
            close all force;
        end
    end

    methods
        function d = makeDoc(~, t, w)
            % a stand-in for the parts of a neuron_extracellular document that
            % plot_extracellular_spikeshapes actually reads
            d = struct('document_properties', ...
                struct('neuron_extracellular', ...
                    struct('mean_waveform', w, 'waveform_sample_times', t)));
        end
    end

    methods (Test)

        function testSharedXLimitsSpanEveryDocument(testCase)
            % The WIDEST document is first on purpose. That is where reading
            % x_axis(1) gives the wrong answer: the upper limit ends up as
            % max(runningMin, lastDocumentMax) = 1 rather than 10, and the
            % wider waveform is clipped out of every panel.
            g = { testCase.makeDoc([-10 0 10], [0;1;0]), ...
                  testCase.makeDoc([-1 0 1], [0;1;0]) };

            ndi.fun.plot_extracellular_spikeshapes([], 1, g);

            A = axis;
            testCase.verifyEqual(A(1), -10, 'AbsTol', 1e-9, ...
                'Lower x-limit should be the minimum across all documents.');
            testCase.verifyEqual(A(2), 10, 'AbsTol', 1e-9, ...
                'Upper x-limit should ACCUMULATE the maximum across all documents.');
        end

        function testWidestDocumentLastAlsoWorks(testCase)
            % The companion ordering. This one passes even with the old
            % expression, so on its own it would have proved nothing -- it is
            % here so the pair pins the behaviour rather than one ordering.
            g = { testCase.makeDoc([-1 0 1], [0;1;0]), ...
                  testCase.makeDoc([-10 0 10], [0;1;0]) };

            ndi.fun.plot_extracellular_spikeshapes([], 1, g);

            A = axis;
            testCase.verifyEqual(A(1), -10, 'AbsTol', 1e-9);
            testCase.verifyEqual(A(2), 10, 'AbsTol', 1e-9);
        end

        function testReturnsTheDocumentsItPlotted(testCase)
            g = { testCase.makeDoc([0 1 2], [0;1;0]) };
            g_out = ndi.fun.plot_extracellular_spikeshapes([], 1, g);
            testCase.verifyEqual(numel(g_out), 1, ...
                'Supplied documents should be returned unchanged.');
        end

    end
end
