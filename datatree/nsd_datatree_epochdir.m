% NSD_DATATREE_EPOCHDIR - Create a new NSD_DATATREE_EPOCHDIR object
%
%  DT = DATATREE_EPOCHDIR(EXP, FILETYPE)   
%
%  Creates a new data tree object with the experiment name 
%  This class in inhereted from datatree and with epochdir organization
%


classdef NSD_datatree_epochdir < handle & NSD_datatree
	properties
	end

	methods

        function obj = NSD_datatree_epochdir(exp, fileparameters)
	% NSD_DATATREE_EPOCHDIR - Create a new NSD_DATATREE_EPOCHDIR object that is associated with an experiment and device
	%
	%   OBJ = NSD_DATATREE_EPOCHDIR(EXP, FILEPARAMETERS)
	%
	% Creates a new NSD_DATATREE_EPOCHDIR object that negotiates the data tree of device's data that is
	% stored in an experiment EXP.
	%
	% (document FILEPARAMETERS)
	%
	% Inputs: EXP - an NSD_EXPERIMENT ; FILEPARAMETERS - the files that are recorded in each epoch
	% Output: OBJ - an NSD_DATATREE_FLAT object
	%
	% See also: NSD_EXPERIMENT, NSD_DEVICE
	%

		obj = obj@NSD_datatree(exp, fileparameters);

        end
        
        function epoch = getepoch(obj, dev, n)  

		error('not implemented yet');

    end
end

