function S = lab(labName, ref, dirname, options)
%NDI.SETUP.LAB Initialize an NDI session directory with lab-specific devices
%
%   S = NDI.SETUP.LAB(LABNAME, REF, DIRNAME)
%   S = NDI.SETUP.LAB(..., 'forceUpdate', TF)
%
%   Initializes an NDI session directory object (ndi.session.dir) for the
%   specified directory DIRNAME. It associates the session with a reference
%   identifier REF and adds the standard set of data acquisition (DAQ) system
%   devices defined for a particular lab, specified by LABNAME.
%
%   The function looks for the DAQ system definitions within the
%   'ndi_common/daq_systems/<labName>' directory, located under the NDI
%   common path (typically found via `ndi.path.commonpath`). If DAQ system
%   devices corresponding to LABNAME already exist in the session directory,
%   they are not added again, unless 'forceUpdate' is true, in which case any
%   existing DAQ systems with these names are removed and re-created.
%
%   Inputs:
%     labName - The name of the lab setup configuration. This determines
%               which set of DAQ system devices are added. Must be a
%               character vector or string scalar (e.g., 'marderlab', "vhlab").
%     ref     - A reference identifier for the session (e.g., an experiment
%               number or unique code). Must be a character vector or string
%               scalar (e.g., '745', "exp001").
%     dirname - The full path to the directory where the NDI session data
%               will be stored. This directory must exist. Must be a
%               character vector or string scalar representing a valid folder path.
%
%   Name-value arguments:
%     forceUpdate - A logical scalar (default false). If true, any DAQ system
%               belonging to LABNAME that already exists in the session is
%               removed and re-installed from the current definition in
%               ndi_common/daq_systems/<labName>. This is useful when the DAQ
%               system definitions have been updated. If false (the default),
%               existing DAQ systems are left untouched.
%
%   Outputs:
%     S       - An ndi.session.dir object representing the initialized
%               session directory, now including the DAQ system devices
%               associated with labName.
%
%   Example:
%       % Define session parameters
%       labId = 'JaneDoeLab'; % Use the specific lab identifier
%       sessionRef = 'exp101_run03';
%       sessionPath = '/path/to/my/data/exp101_run03';
%
%       % Create the directory if it doesn't exist
%       if ~exist(sessionPath, 'dir'), mkdir(sessionPath); end
%
%       % Initialize the session with lab-specific devices
%       mySession = ndi.setup.lab(labId, sessionRef, sessionPath);
%
%       % Re-install the lab's DAQ systems, discarding any existing ones
%       mySession = ndi.setup.lab(labId, sessionRef, sessionPath, ...
%           'forceUpdate', true);
%
%   See also: ndi.session.dir, ndi.setup.daq.addDaqSystems,
%             ndi.setup.sync.addSyncRules, ndi.path.commonpath

    % Input argument validation block
    arguments
        labName (1,:) {mustBeTextScalar} % Lab name must be char vector or string scalar
        ref (1,:) {mustBeTextScalar}     % Reference must be char vector or string scalar
        dirname (1,:) {mustBeFolder, mustBeTextScalar} % Directory must exist and be text
        options.forceUpdate (1,1) logical = false % Remove and re-create existing DAQ systems
    end

    % Create the session directory object
    S = ndi.session.dir(ref, dirname);

    % Add the DAQ systems associated with the specified lab name
    % This function typically finds definitions in ndi.path.commonpath/daq_systems/labName
    % If options.forceUpdate is true, existing DAQ systems with these names are
    % removed from the session before being re-created.
    S = ndi.setup.daq.addDaqSystems(S, labName, options.forceUpdate);

    % by default, include syncrule for same file names
    nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
    S.syncgraph_addrule(nsf);

    % Add any lab-specific synchronization rules. These are defined in
    % ndi_common/sync_rules/<labName> and are the syncgraph counterpart to the
    % DAQ systems added above. Labs without extra rules are left unchanged.
    S = ndi.setup.sync.addSyncRules(S, labName);

end % function lab
