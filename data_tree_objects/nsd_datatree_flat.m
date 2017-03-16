% NSD_DATATREE_FLAT - Create a new NSD_DATATREE_FLAT object
%
%  DT = DATATREE_FLAT(EXP, FILETYPE)   
%
%  Creates a new data tree object with the experiment name 
%  This class in inhereted from datatree and with flat organization
%


classdef nsd_datatree_flat < handle & nsd_datatree
	properties
	end

	methods

	function obj = nsd_datatree_flat(exp_, fileparameters_)
	% NSD_DATATREE_FLAT - Create a new NSD_DATATREE_FLAT object that is associated with an experiment and device
	%
        %   OBJ = NSD_DATATREE_FLAT(EXP, FILEPARAMETERS)
        %
        % Creates a new NSD_DATATREE_FLAT object that negotiates the data tree of device's data that is
        % stored in an experiment EXP.
	% 
	% (document FILEPARAMETERS)
        %
        % Inputs: EXP - an NSD_EXPERIMENT ; FILEPARAMETERS - the files that are recorded in each epoch of DEVICE
        % Output: OBJ - an NSD_DATATREE_FLAT object
        %
        % See also: NSD_EXPERIMENT, NSD_DEVICE
        %

		% need to fix inherentence 
		nsd_datatree_flat.nsd_datatree = nsd_datatree(exp_,fileparameters_);

        end
        
        function epoch = getepoch(self, n)  

		allfiles = findfiletype(self.exp.getpath(), fileparameters);

		if length(allfiles) <= query,
		        files = allfiles(query);
		else,
		        error(['There is not an epoch numbered ' int2str(query) '; only ' int2str(length(allfiles)) ' epochs found.']);
		end;
        end;

	end; % methods
end % object

