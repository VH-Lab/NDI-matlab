function names = labNames()
%NDI.SETUP.LABNAMES List the lab names known to ndi.setup.lab
%
%   NAMES = NDI.SETUP.LABNAMES()
%
%   Returns a cell array of the lab names that can be passed as the LABNAME
%   argument to ndi.setup.lab(LABNAME, REF, DIRNAME). A lab is "known" if it
%   has a directory of DAQ system configuration files under
%   'ndi_common/daq_systems/<LABNAME>' (located via ndi.path.commonpath).
%
%   The names are returned sorted alphabetically. If no DAQ system
%   configurations are installed, an empty cell array is returned.
%
%   Example:
%       labs = ndi.setup.labNames();
%       % labs = {'angeluccilab','dabrowskalab',...,'vhlab',...}
%
%   See also: ndi.setup.lab, ndi.setup.daq.addDaqSystems,
%             ndi.setup.daq.system.listDaqSystemNames, ndi.path.commonpath

    daqSystemsDir = fullfile(ndi.common.PathConstants.CommonFolder, 'daq_systems');

    names = {};
    if ~isfolder(daqSystemsDir)
        return;
    end

    d = dir(daqSystemsDir);
    d = d([d.isdir]);                                        % directories only
    d = d(~ismember({d.name}, {'.', '..'}));                 % drop . and ..
    isvis = arrayfun(@(e) ~isempty(e.name) && e.name(1) ~= '.', d);
    d = d(isvis);                                            % drop hidden dirs

    names = sort({d.name});
    if ~iscell(names)
        names = {names};
    end
end % function labNames
