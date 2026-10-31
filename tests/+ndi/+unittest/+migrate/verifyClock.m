function verifyClock(testCase, clk, handle, msg)
%VERIFYCLOCK Verify a stored clock term is the clock HANDLE, by node first.
%
%   ndi.unittest.migrate.verifyClock(TESTCASE, CLK, HANDLE) verifies that CLK
%   (a relative_time_reference `value.clock` or a clock_alignment_configuration
%   `clock`: a {node, name} struct, or a 1-element cell of one) is the clock
%   whose did_v1 clocktype string is HANDLE ('utc', 'dev_local_time',
%   'dev_global_time', 'exp_global_time'):
%     1. its NODE is the decided node of HANDLE;
%     2. ndi.v2.vocabHandle('clock', CLK) answers HANDLE;
%     3. its stored NAME is HANDLE (did-schema before the flip) or the term
%        LABEL (after it) -- nothing else.
%
%   WHY. Decided by Jess Haley, 2026-10-26 [clock terms get nodes] (did-schema
%   did_v2_go_forward_class_audit.md; [census terms] T4): utc wikidata:Q1536
%   "UTC", dev_local_time EMPTY:0000403 "device local time", dev_global_time
%   EMPTY:0000404 "device global time", exp_global_time EMPTY:0000405
%   "experiment global time" (did-schema did_v2_term_registry.json); "the
%   stored name becomes the term label, so DID-matlab and NDI-matlab compare
%   clock nodes first before the schema changes". A test that pins the stored
%   name 'dev_local_time' fails the day did-schema stores the label, so the
%   tests compare by node and admit either spelling of the name.
%
%   The table is written out here, not read from ndi.v2.vocabNodes, so
%   the code under test is not also the oracle.
%
%   See also ndi.v2.vocabHandle, ndi.v2.vocabNodes.

if nargin < 4; msg = ''; end
decided = {
    'utc',             'wikidata:Q1536', 'UTC'
    'dev_local_time',  'EMPTY:0000403',  'device local time'
    'dev_global_time', 'EMPTY:0000404',  'device global time'
    'exp_global_time', 'EMPTY:0000405',  'experiment global time'};
row = find(strcmp(decided(:, 1), handle), 1);
assert(~isempty(row), 'verifyClock: "%s" is not one of the four clocks', handle);

if iscell(clk) && isscalar(clk); clk = clk{1}; end
testCase.assertTrue(isstruct(clk) && isscalar(clk) && isfield(clk, 'node') ...
    && isfield(clk, 'name'), ...
    sprintf('%s the clock is not a {node, name} term', msg));
testCase.verifyEqual(char(clk.node), decided{row, 2}, ...
    sprintf('%s the clock does not carry the decided node of %s', msg, handle));
testCase.verifyEqual(char(ndi.v2.vocabHandle('clock', clk)), handle, ...
    sprintf('%s the clock does not read back as %s', msg, handle));
testCase.verifyTrue(any(strcmp(char(clk.name), decided(row, [1 3]))), ...
    sprintf('%s stored name "%s" is neither "%s" nor "%s"', msg, char(clk.name), ...
    decided{row, 1}, decided{row, 3}));
end
