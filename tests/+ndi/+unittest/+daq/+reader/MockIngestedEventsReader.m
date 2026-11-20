classdef MockIngestedEventsReader < ndi.daq.reader.mfdaq
    % MockIngestedEventsReader - an mfdaq reader whose ingested epoch is given
    %
    % R = ndi.unittest.daq.reader.MockIngestedEventsReader(A, T0T1)
    %
    % GETINGESTEDARCHIVE returns A (as ndi.daq.reader/getingestedarchive
    % describes it: a v1 archive with A.doc, or a v2 archive with A.events)
    % and T0_T1_INGESTED returns T0T1, so READEVENTS_EPOCHSAMPLES_INGESTED
    % runs unchanged on events the test writes, with no database.
    % Used with ndi.unittest.daq.reader.MockBinarySession.

    properties
        Archive
        T0T1
    end

    methods
        function obj = MockIngestedEventsReader(A, t0t1)
            obj = obj@ndi.daq.reader.mfdaq();
            obj.Archive = A;
            obj.T0T1 = t0t1;
        end

        function A = getingestedarchive(obj, epochfiles, S, varargin)
            A = obj.Archive;
        end

        function t0t1 = t0_t1_ingested(obj, epochfiles, S)
            t0t1 = obj.T0T1;
        end
    end
end
