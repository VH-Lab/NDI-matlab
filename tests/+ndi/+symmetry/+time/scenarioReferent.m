classdef scenarioReferent < ndi.epoch.epochset & ndi.ido
    % scenarioReferent - a minimal ndi.epoch.epochset built from a data scenario
    %
    %   The cross-language time/syncgraph symmetry check drives the real
    %   ndi.time.syncgraph/time_convert over a fixed, self-describing scenario
    %   (see ndi.symmetry.time.scenario). This class is the MATLAB counterpart
    %   of the Python tests/symmetry/_time_scenario.py "_SpecRef": a referent
    %   whose epochtable is built directly from the scenario data, so the
    %   artifact is reproducible from the spec alone.
    %
    %   ⚠️ AUTHORED WITHOUT A MATLAB RUNTIME — VALIDATE BEFORE RELYING ON IT.
    %   The same-referent path of time_convert (which every scenario case uses)
    %   only needs this referent's epochtable plus a valid .session; it does not
    %   build the syncgraph. Points to confirm on first MATLAB run:
    %     * ndi.epoch.epochset & ndi.ido combine cleanly and == compares by id.
    %     * buildepochtable's field set/order matches what epochset.epochtable
    %       and time_convert expect (epoch_clock is a CELL array of clocktypes,
    %       t0_t1 a CELL array of [t0 t1] pairs).
    %     * the referent's .session is a real ndi.session (timereference
    %       requires isa(referent.session,'ndi.session')).

    properties
        session        % ndi.session object (required by ndi.time.timereference)
        ScenarioName char
        ScenarioEpochs struct   % fields: epoch_id (char), clocks (cellstr), t0_t1 (cell of [t0 t1])
    end

    methods
        function obj = scenarioReferent(session, name, scenarioEpochs)
            obj = obj@ndi.ido();
            obj.session = session;
            obj.ScenarioName = name;
            obj.ScenarioEpochs = scenarioEpochs;
        end

        function name = epochsetname(obj)
            name = obj.ScenarioName;
        end

        function et = buildepochtable(obj)
            % BUILDEPOCHTABLE - assemble the epochtable from the scenario data,
            % in the format documented by ndi.epoch.epochset (epoch_clock and
            % t0_t1 are CELL arrays, parallel per clock).
            et = vlt.data.emptystruct('epoch_number', 'epoch_id', ...
                'epoch_session_id', 'epochprobemap', 'epoch_clock', ...
                't0_t1', 'underlying_epochs');
            for i = 1:numel(obj.ScenarioEpochs)
                e = obj.ScenarioEpochs(i);
                clocks = cell(1, numel(e.clocks));
                for k = 1:numel(e.clocks)
                    clocks{k} = ndi.time.clocktype(e.clocks{k});
                end
                entry.epoch_number      = i;
                entry.epoch_id          = e.epoch_id;
                entry.epoch_session_id  = obj.session.id();
                entry.epochprobemap     = [];
                entry.epoch_clock       = clocks;      % cell array of clocktype
                entry.t0_t1             = e.t0_t1;     % cell array of [t0 t1]
                entry.underlying_epochs = vlt.data.emptystruct('underlying', ...
                    'epoch_id', 'epoch_session_id', 'epochprobemap', ...
                    'epoch_clock', 't0_t1');
                et(end+1) = entry; %#ok<AGROW>
            end
        end
    end
end
