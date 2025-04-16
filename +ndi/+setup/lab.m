function S = lab(labName, ref, dirname)
%NDI.SETUP.LAB Initialize an NDI session directory with lab-specific devices
%
%   S = NDI.SETUP.LAB(LABNAME, REF, DIRNAME)
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
%   they are not added again.
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
%   See also: ndi.session.dir, ndi.setup.daq.addDaqSystems, ndi.path.commonpath

    % Input argument validation block
    arguments
        labName (1,:) {mustBeTextScalar} % Lab name must be char vector or string scalar
        ref (1,:) {mustBeTextScalar}     % Reference must be char vector or string scalar
        dirname (1,:) {mustBeFolder, mustBeTextScalar} % Directory must exist and be text
    end

    % Create the session directory object
    S = ndi.session.dir(ref, dirname);

    % Add the DAQ systems associated with the specified lab name
    % This function typically finds definitions in ndi.path.commonpath/daq_systems/labName
    S = ndi.setup.daq.addDaqSystems(S, labName);

    % by default, include syncrule for same file names
    nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
    S.syncgraph_addrule(nsf);

end % function lab
