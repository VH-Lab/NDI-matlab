function S = rayolab(ref, dirname)
%NDI.SETUP.RAYOLAB Initialize an NDI session directory with RayoLab devices.
%
%   S = NDI.SETUP.RAYOLAB(REF, DIRNAME)
%
%   Initializes an ndi.session.dir object for the directory DIRNAME with
%   the standard RayoLab DAQ system configurations, as defined in
%   "ndi_common/daq_systems/rayolab". If the devices are already added
%   to the session, they are not re-created.
%
%   The RayoLab setup currently includes the rayo_intanSeries device,
%   which uses ndi.file.navigator.rhd_series to group recordings by
%   filename prefix and select only the earliest file in each prefix
%   group. The companion epochprobemap file is selected the same way.
%   Acquisition is read by ndi.daq.reader.mfdaq.ndr configured with the
%   NDR-matlab "intan" reader (an alias for ndr.reader.intan_rhd).
%
%   Inputs:
%     ref     - Reference identifier for the session (char or string).
%     dirname - Full path to the existing session directory.
%
%   Output:
%     S       - The ndi.session.dir object with RayoLab DAQ systems
%               added.
%
%   Example:
%       S = ndi.setup.rayolab('exp001', '/path/to/session');
%
%   See also: ndi.setup.lab, ndi.session.dir,
%             ndi.file.navigator.rhd_series,
%             ndi.daq.reader.mfdaq.ndr

    arguments
        ref (1,:) {mustBeTextScalar}
        dirname (1,:) {mustBeFolder, mustBeTextScalar}
    end

    S = ndi.setup.lab('rayolab', ref, dirname);
end
