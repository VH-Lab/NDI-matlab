% NSD_FILETREE_EPOCHDIR - Create a new NSD_FILETREE_EPOCHDIR object
%
%  DT = FILETREE_EPOCHDIR(EXP, FILETYPE)   
%
%  Creates a new data tree object with the experiment name 
%  This class in inhereted from filetree and with epochdir organization
%


classdef nsd_filetree_epochdir < handle & nsd_filetree
	properties
	end

	methods

        function obj = nsd_filetree_epochdir(exp, fileparameters)
	% NSD_FILETREE_EPOCHDIR - Create a new NSD_FILETREE_EPOCHDIR object that is associated with an experiment and device
	%
	%   OBJ = NSD_FILETREE_EPOCHDIR(EXP, FILEPARAMETERS)
	%
	% Creates a new NSD_FILETREE_EPOCHDIR object that negotiates the data tree of device's data that is
	% stored in an experiment EXP.
	%
	% (document FILEPARAMETERS)
	%
	% Inputs: EXP - an NSD_EXPERIMENT ; FILEPARAMETERS - the files that are recorded in each epoch
	% Output: OBJ - an NSD_FILETREE_FLAT object
	%
	% See also: NSD_EXPERIMENT, NSD_DEVICE
	%

		obj = obj@nsd_filetree(exp, fileparameters);

        end
        
        function epoch = getepoch(obj, dev, n)  

		error('not implemented yet');

    end
end

