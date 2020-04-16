classdef ndi_neuron_hengen < ndi_thing_timeseries
	properties (SetAccess=protected, GetAccess=public)
		quality
		source
	end

	methods
		function ndi_neuron_hengen_obj = ndi_neuron_hengen(varargin)

			ndi_neuron_hengen_obj = ndi_neuron_hengen_obj@ndi_thing_timeseries(varargin{:});

			ndi_neuron_hengen_obj.quality = varargin{7};
			ndi_neuron_hengen_obj.source = varargin{8};
		end

		function ndi_document_obj = newdocument(ndi_neuron_hengen_obj)
			% NEWDOCUMENT - return a new database document of type NDI_DOCUMENT based on a neuron_hengen
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(ndi_neuron_hengen_obj)
			%
			% Fill out the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_thing'
			% with the corresponding 'name' and 'type' fields of the thing NDI_NEURON_HENGEN_OBJ and the 
			% 'name', 'type', and 'reference' fields of its underlying NDI_PROBE_OBJ. 
			% If EPOCHID is provided, then an EPOCHID field is filled out as well
			% in accordance to 'ndi_document_epochid'.
			%
			% When the document is created, it is automatically added to the experiment.
			%
				ndi_document_obj = ndi_neuron_hengen_obj.load_thing_doc();
				if isempty(ndi_document_obj),
					ndi_document_obj = ndi_document('ndi_document_thing',...
						'thing.ndi_thing_class', class(ndi_neuron_hengen_obj), ...
						'thing.name',ndi_neuron_hengen_obj.name,...
						'thing.reference', ndi_neuron_hengen_obj.reference, ...
						'thing.type',ndi_neuron_hengen_obj.type, ...
						'thing.direct',ndi_neuron_hengen_obj.direct,...
						'thing.quality', ndi_neuron_hengen_obj.quality,...
						'thing.source', ndi_neuron_hengen_obj.source);
					ndi_document_obj = ndi_document_obj + ...
						newdocument(ndi_neuron_hengen_obj.experiment, 'ndi_document', 'ndi_document.type','ndi_thing');
					underlying_id = [];
					if ~isempty(ndi_neuron_hengen_obj.underlying_thing),
						underlying_id = ndi_neuron_hengen_obj.underlying_thing.id();
						if isempty(underlying_id), % underlying thing hasn't been saved yet
							newdoc = ndi_neuron_hengen_obj.underlying_thing.newdocument();
							underlying_id = newdoc.id();
						end;
					end;
					ndi_document_obj = set_dependency_value(ndi_document_obj,'underlying_thing_id',underlying_id);
					ndi_neuron_hengen_obj.experiment.database_add(ndi_document_obj);
				end;
		end; % newdocument()
	end

end % classdef
