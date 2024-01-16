classdef metadatareader < ndi.ido & ndi.documentservice
% NDI.DAQ.METADATAREADER.BASE - a class for reading metadata related to data acquisition, such as stimulus parameter information
%
% 

	properties (GetAccess=public, SetAccess=protected)
		tab_separated_file_parameter   % regular expression to search within epochfiles for a
		                               %   tab-separated-value file that describes stimulus
		                               %   parameters
	end;
	properties (Access=private)
	end;

	methods

		function obj = metadatareader(varargin)
			% ndi.daq.metadatareader - Create a new multifunction DAQ object
			%
			%  D = ndi.daq.metadatareader()
			%  or
			%  D = ndi.daq.metadatareader(TSVFILE_REGEXPRESSION)
			%
			%  Creates a new ndi.daq.metadatareader object. If TSVFILE_REGEXPRESSION
			%  is given, it indicates a regular expression to use to search EPOCHFILES
			%  for a tab-separated-value text file that describes stimulus parameters.
			%
				tsv_p = '';
				if nargin==1,
					tsv_p = varargin{1};
					varargin = {};
				end;

				if (nargin==2) & (isa(varargin{1},'ndi.session')) & (isa(varargin{2},'ndi.document')),
                                	obj.identifier = varargin{2}.document_properties.base.id;
					if isfield(varargin{2}.document_properties,'daqmetadatareader'),
						tsv_p = varargin{2}.document_properties.daqmetadatareader.tab_separated_file_parameter;
					end;
				end;
				obj.tab_separated_file_parameter = tsv_p;
		end; % ndi.daq.metadatareader

		function parameters = readmetadata(ndi_daqmetadatareader_obj, epochfiles)
			% PARAMETERS = READMETADATA(NDI_DAQSYSTEM_STIMULUS_OBJ, EPOCHFILES)
			%
			% Returns the parameters (cell array of structures) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch with file list EPOCHFILES.
			%
			% If the property 'tab_separated_file_parameter' is not empty, then EPOCHFILES will be searched for
			% files that match the regular expression in 'tab_separated_file_parameter'. The tab-separated-value
			% file should have the form:
			%
			% STIMID<tab>PARAMETER1<tab>PARAMETER2<tab>PARAMETER3 (etc) <newline>
			% 1<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc) <newline>
			% 2<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc) <newline>
			%  (etc)
			%
			% For example, a stimulus file for an interoral cannula might be:
			% stimid<tab>substance1<tab>substance1_concentration<newline>
			% 1<tab>Sodium chloride<tab>30e-3<newline>
			% 2<tab>Sodium chloride<tab>300e-3<newline>
			% 3<tab>Quinine<tab>30e-6<newline>
			% 4<tab>Quinine<tab>300e-6<newline>
			%
			% This function can be overridden in more specialized stimulus classes.
			%
				parameters = {};
				if ~isempty(ndi_daqmetadatareader_obj.tab_separated_file_parameter),
					tf = regexpi(epochfiles, ...
						ndi_daqmetadatareader_obj.tab_separated_file_parameter,...
						'forceCellOutput');
					tf = find(~cellfun(@isempty,tf));
					if numel(tf)>1,
						error(['More than one epochfile matches regular expression ' ...
							ndi_daqmetadatareader_obj.tab_separated_file_parameter ...
							'; epochfiles were ' epochfiles{:} '.']);
					elseif numel(tf)==0,
						error(['No epochfiles match regular expression ' ...
							ndi_daqmetadatareader_obj.tab_separated_file_parameter ...
							'; epochfiles were ' epochfiles{:} '.']);

					else,
						if ~exist(epochfiles{tf},'file'),
							error(['No such file ' file '.']);
						end;
						parameters = ndi_daqmetadatareader_obj.readmetadatafromfile(epochfiles{tf});
					end;
				end;
		end; % readmetadata()

		function parameters = readmetadatafromfile(ndi_daqmetadatareader_obj, file)
			% PARAMETERS = READMETADATAFROMFILE - read in metadata from the file that is identified
			%
			% PARAMETERS = READMETADATAFROMFILE(NDI_DAQMETADATAREADER_OBJ, FILE)
			%
			% Given a file that matches the metadata search criteria for an ndi.daq.metadatareader
			% document, this function loads in the metadata.
				parameters = {};
				stimparameters = vlt.file.loadStructArray(file);
				for i=1:numel(stimparameters),
					parameters{i} = stimparameters(i);
				end;
		end;  % readmetadata

		function d = ingest_epochfiles(ndi_daqmetadatareader_obj, epochfiles)
			% INGEST_EPOCHFILES - create an ndi.document that describes the data that is read by an ndi.daq.metadatareader
			%
			% D = INGEST_EPOCHFILES(NDI_DAQMETADATAREADER_OBJ, EPOCHFILES)
			%
			% Creates an ndi.document of type 'daqmetadatareader_epochdata_ingested' that contains the data
			% for an ndi.daq.metadatareaderobject. The document D is not added to any database.
			%

				d = ndi.document('daqmetadatareader_epochdata_ingested');
				d = d.set_dependency_value('daqmetadatareader_id',ndi_daqmetadatareader_obj.id());
				
				filenames_we_made = {};

				parameters = ndi_daqmetadatareader_obj.readmetadata(epochfiles);
				metadatafile = ndi.file.temp_name();
				[ratio] = ndi.compress.compress_metadata(parameters,metadatafile);
				d = d.add_file('data.bin',[metadatafile '.nbf.tgz']);
				filenames_we_made = {metadatafile};

		end;

		function tf = eq(ndi_daqmetadatareader_obj_a, ndi_daqmetadatareader_obj_b)
			% EQ - are 2 ndi.daq.metadatareader objects equal?
			%
			% TF = EQ(NDI_DAQMETADATAREADER_OBJ_A, NDI_DAQMETADATAREADER_OBJ_B)
			%
			% TF is 1 if the two objects are of the same class and have the same properties.
			% TF is 0 otherwise.
				tf = 0;
				if strcmp(class(ndi_daqmetadatareader_obj_a),class(ndi_daqmetadatareader_obj_b)),
					tf = vlt.data.eqlen(properties(ndi_daqmetadatareader_obj_a),properties(ndi_daqmetadatareader_obj_b));
				end;
		end; % eq()

		% documentservices overriden methods

		function ndi_document_obj = newdocument(ndi_daqmetadatareader_obj)
			% NEWDOCUMENT - create a new ndi.document for an ndi.daq.metadatareader object
			%
			% DOC = NEWDOCUMENT(ndi.daq.metadatareader OBJ)
			%
			% Creates an ndi.document object DOC that represents the
			%    ndi.daq.reader object.
				ndi_document_obj = ndi.document('daq/daqmetadatareader',...
					'daqmetadatareader.ndi_daqmetadatareader_class',class(ndi_daqmetadatareader_obj),...
					'daqmetadatareader.tab_separated_file_parameter', ndi_daqmetadatareader_obj.tab_separated_file_parameter, ...
					'base.id', ndi_daqmetadatareader_obj.id(),...
					'base.session_id',ndi.session.empty_id());
		end; % newdocument()

		function sq = searchquery(ndi_daqmetadatareader_obj)
			% SEARCHQUERY - create a search for this ndi.daq.reader object
			%
			% SQ = SEARCHQUERY(NDI_DAQMETADATAREADER_OBJ)
			%
			% Creates a search query for the ndi.daq.metadatareader object.
			%
				sq = ndi.query('base.id','exact_string',ndi_daqmetadatareader_obj.id(),'');
		end; % searchquery()

	end; % methods

end % classdef
