function S = vhlab(ref, dirname, force)
% ndi.setup.vhlab - initialize an ndi.session.dir with VHLAB devices
%
%  S = ndi.setup.vhlab(REF, DIRNAME, [FORCE])
%
%  Initializes an ndi.session.dir object for the directory
%  DIRNAME with the standard compliment of VHLAB devices, as
%  found in "ndi_common/daq_systems/vhlab".
%
%  If the devices are already added, they are not re-created unless
%  FORCE is provided and is 1.

    if nargin < 3; force = 0; end

    S = ndi.session.dir(ref, dirname);
    S = ndi.setup.daq.addDaqSystems(S, 'vhlab', force);

    % update SYNCGRAPH
    nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
    n_intan2spike2 = ndi.time.syncrule.filefind(struct('number_fullpath_matches',1, ...
	    'syncfilename','vhintan_intan2spike2time.txt',...
	    'daqsystem1','vhintan','daqsystem2','vhvis_spike2'));
    
    S.syncgraph_addrule(nsf);
    S.syncgraph_addrule(n_intan2spike2);
end
