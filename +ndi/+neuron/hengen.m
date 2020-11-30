classdef hengen < ndi.element.timeseries
	properties (SetAccess=protected, GetAccess=public)
		quality
		source
	end

	methods
		function ndi_neuron_hengen_obj = hengen(varargin)

			ndi_neuron_hengen_obj = ndi_neuron_hengen_obj@ndi.element.timeseries(varargin{:});
    
			if numel(varargin) == 2
				ndi_neuron_hengen_obj.quality = varargin{2}.document_properties.element.quality;
				ndi_neuron_hengen_obj.source = varargin{2}.document_properties.element.source;
			else
				ndi_neuron_hengen_obj.quality = varargin{7};
				ndi_neuron_hengen_obj.source = varargin{8};
			end
			
		end; % ndi.neuron.hengen()

		function ndi_document_obj = newdocument(ndi_neuron_hengen_obj)
			% NEWDOCUMENT - return a new database document of type ndi.document based on a neuron_hengen
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(ndi_neuron_hengen_obj)
			%
			% Fill out the fields of an NDI_DOCUMENT_OBJ of type 'ndi_document_element'
			% with the corresponding 'name' and 'type' fields of the element NDI_NEURON_HENGEN_OBJ and the 
			% 'name', 'type', and 'reference' fields of its underlying NDI_PROBE_OBJ. 
			% If EPOCHID is provided, then an EPOCHID field is filled out as well
			% in accordance to 'ndi_document_epochid'.
			%
			% When the document is created, it is automatically added to the session
			%
				ndi_document_obj = ndi_neuron_hengen_obj.load_element_doc();
				if isempty(ndi_document_obj),
					ndi_document_obj = ndi.document('ndi_document_element_neuron_hengen',...
						'element.ndi_element_class', class(ndi_neuron_hengen_obj), ...
						'element.name',ndi_neuron_hengen_obj.name,...
						'element.reference', ndi_neuron_hengen_obj.reference, ...
						'element.type',ndi_neuron_hengen_obj.type, ...
						'element.direct',ndi_neuron_hengen_obj.direct,...
						'neuron_hengen.quality', ndi_neuron_hengen_obj.quality,...
						'neuron_hengen.source', ndi_neuron_hengen_obj.source);
					ndi_document_obj = ndi_document_obj + ...
						newdocument(ndi_neuron_hengen_obj.session, 'ndi_document', 'ndi_document.type','ndi_element');
					underlying_id = [];
					if ~isempty(ndi_neuron_hengen_obj.underlying_element),
						underlying_id = ndi_neuron_hengen_obj.underlying_element.id();
						if isempty(underlying_id), % underlying element hasn't been saved yet
							newdoc = ndi_neuron_hengen_obj.underlying_element.newdocument();
							underlying_id = newdoc.id();
						end;
					end;
					ndi_document_obj = set_dependency_value(ndi_document_obj,'underlying_element_id',underlying_id);
					ndi_neuron_hengen_obj.session.database_add(ndi_document_obj);
				end;
		end; % newdocument()
	end

end % classdef
