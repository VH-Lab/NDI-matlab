classdef scenario
    % scenario - shared, self-describing time/syncgraph symmetry scenario
    %
    %   MATLAB counterpart of the Python tests/symmetry/_time_scenario.py. Both
    %   language ports build a referent from the same SCENARIO (a referent with
    %   two multi-clock epochs), run the same CASES through their real
    %   ndi.time.syncgraph/time_convert, and must agree on the recorded outputs
    %   (out_time / out_epoch / msg) written to timeConvertCases.json.
    %
    %   Every case is same-referent (in_ref == out_ref == "probeA"), so
    %   time_convert resolves it from the referent's epochtable alone (the
    %   same-referent fast path) — no syncgraph construction, no DAQ readers.
    %
    %   ⚠️ AUTHORED WITHOUT A MATLAB RUNTIME — VALIDATE BEFORE RELYING ON IT.
    %   See ndi.symmetry.time.scenarioReferent for the referent-format notes;
    %   the make test only writes the artifact if every case converts cleanly,
    %   so an unvalidated referent cannot regress the rest of the symmetry suite.

    methods (Static)

        function s = scenarioStruct()
            % SCENARIOSTRUCT - the data the referent + the JSON "scenario" block
            % are built from. Mirrors Python SCENARIO.
            ep1.epoch_id = 'ep1';
            ep1.clocks   = {'dev_local_time', 'exp_global_time'};
            ep1.t0_t1    = {[0 10], [100 110]};
            ep2.epoch_id = 'ep2';
            ep2.clocks   = {'dev_local_time', 'exp_global_time'};
            ep2.t0_t1    = {[0 5], [200 205]};
            r.name   = 'probeA';
            r.id     = 'id_probeA';
            r.epochs = [ep1 ep2];
            s.referents = r;
        end

        function defs = caseDefs()
            % CASEDEFS - the 7 input cases. out_* are placeholders filled by
            % runCases. Text fields are strings (so a missing epoch encodes as
            % JSON null, matching Python's None); times are doubles (NaN -> null).
            mk = @(ir, ic, ie, it, orf, oc) struct( ...
                'in_ref', string(ir), 'in_clock', string(ic), 'in_epoch', ie, ...
                'in_time', it, 'out_ref', string(orf), 'out_clock', string(oc), ...
                'out_time', NaN, 'out_epoch', string(missing), 'msg', "");
            defs = mk("probeA", "dev_local_time", "ep1", 5.0,  "probeA", "dev_local_time");
            defs(end+1) = mk("probeA", "dev_local_time", "ep1", 5.0,  "probeA", "exp_global_time");
            defs(end+1) = mk("probeA", "dev_local_time", "ep1", 0.0,  "probeA", "exp_global_time");
            defs(end+1) = mk("probeA", "dev_local_time", "ep1", 10.0, "probeA", "exp_global_time");
            defs(end+1) = mk("probeA", "dev_local_time", "ep2", 2.5,  "probeA", "exp_global_time");
            defs(end+1) = mk("probeA", "exp_global_time", string(missing), 105.0, "probeA", "exp_global_time");
            defs(end+1) = mk("probeA", "exp_global_time", string(missing), 202.5, "probeA", "exp_global_time");
        end

        function referent = buildReferent(session)
            % BUILDREFERENT - construct the scenario referent on a live session.
            s = ndi.symmetry.time.scenario.scenarioStruct();
            r = s.referents(1);
            referent = ndi.symmetry.time.scenarioReferent(session, r.name, r.epochs);
        end

        function results = runCases(session)
            % RUNCASES - run every CASE through the real time_convert and return
            % the cases with out_time/out_epoch/msg filled in. Errors are
            % recorded as data (msg = "ERROR:...") rather than thrown, mirroring
            % the Python run_cases.
            defs = ndi.symmetry.time.scenario.caseDefs();
            referent = ndi.symmetry.time.scenario.buildReferent(session);
            sg = ndi.time.syncgraph(session);   % graph unused on the same-referent path
            results = defs;
            for i = 1:numel(defs)
                c = defs(i);
                ctIn  = ndi.time.clocktype(char(c.in_clock));
                ctOut = ndi.time.clocktype(char(c.out_clock));
                if ismissing(c.in_epoch)
                    ep = [];
                else
                    ep = char(c.in_epoch);
                end
                try
                    trefIn = ndi.time.timereference(referent, ctIn, ep, 0);
                    [tOut, trefOut, msg] = sg.time_convert(trefIn, c.in_time, referent, ctOut);
                    if isempty(tOut)
                        results(i).out_time = NaN;
                    else
                        results(i).out_time = round(double(tOut), 9);
                    end
                    if isempty(trefOut) || isempty(trefOut.epoch)
                        results(i).out_epoch = string(missing);
                    else
                        results(i).out_epoch = string(trefOut.epoch);
                    end
                    results(i).msg = string(msg);
                catch ME
                    results(i).out_time  = NaN;
                    results(i).out_epoch = string(missing);
                    eid = ME.identifier; if isempty(eid), eid = 'error'; end
                    results(i).msg = "ERROR:" + string(eid);
                end
            end
        end

        function exp = expected()
            % EXPECTED - the MATLAB-authoritative correct outputs for caseDefs,
            % in the same order. MATLAB is the symmetry reference; Python must
            % match these. Derived from the NDI time model: within an epoch,
            % time rescales linearly between the two clocks' [t0 t1] ranges, and
            % same-clock conversions are the identity.
            mk = @(t, e) struct('exp_time', t, 'exp_epoch', string(e));
            exp = mk(5.0,   "ep1");          % dev_local ep1 t=5 -> dev_local (identity)
            exp(end+1) = mk(105.0, "ep1");   % dev_local [0 10] -> exp_global [100 110]: 5 -> 105
            exp(end+1) = mk(100.0, "ep1");   % 0 -> 100
            exp(end+1) = mk(110.0, "ep1");   % 10 -> 110
            exp(end+1) = mk(202.5, "ep2");   % ep2 [0 5] -> [200 205]: 2.5 -> 202.5
            exp(end+1) = mk(105.0, "ep1");   % exp_global 105 (in ep1) -> exp_global (identity)
            exp(end+1) = mk(202.5, "ep2");   % exp_global 202.5 (in ep2) -> exp_global (identity)
        end

        function verifyExpected(testCase, results)
            % VERIFYEXPECTED - assert computed RESULTS match the expected
            % (reference) outputs case-by-case.
            exp = ndi.symmetry.time.scenario.expected();
            testCase.verifyEqual(numel(results), numel(exp), ...
                'Number of results does not match number of expected cases.');
            for i = 1:numel(exp)
                testCase.verifyEqual(double(results(i).out_time), exp(i).exp_time, ...
                    'AbsTol', 1e-9, sprintf('Case %d out_time mismatch.', i));
                testCase.verifyEqual(string(results(i).out_epoch), exp(i).exp_epoch, ...
                    sprintf('Case %d out_epoch mismatch.', i));
            end
        end

        function artifactDir(sourceType)
            % ARTIFACTDIR - not used directly; the layout is documented in the
            % make/read tests:
            %   <tempdir>/NDI/symmetryTest/<sourceType>/time/timeConvert/
            %            testTimeConvertArtifacts/timeConvertCases.json
        end
    end
end
