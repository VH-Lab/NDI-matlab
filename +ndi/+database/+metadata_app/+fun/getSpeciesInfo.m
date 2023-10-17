function [name, ontology_identifier, synonym] = getSpeciesInfo(uuid)
    database = "taxonomy";
    base_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils";
    doc_url = sprintf("efetch.fcgi?db=%s&id=%d", database, uuid);
    search_result = webread(base_url+"/"+doc_url);
    
    global ndi_globals;
    temp_dir = ndi_globals.path.temppath;
    ido_ = ndi.ido;
    rand_num = ido_.identifier;
    temp_filename = sprintf("search_result_%s.xml", rand_num);
    file_path = fullfile(temp_dir,temp_filename);
    
    fid = fopen(file_path,'w');
    fprintf(fid,'%s',search_result);
    fclose(fid);
    
    species_info = readstruct(file_path);
    if isfield(species_info.Taxon, 'ScientificName')
        name = species_info.Taxon.ScientificName;
    else
        name = "";
    end
    if isfield(species_info.Taxon.OtherNames, 'Synonym')
        synonym = species_info.Taxon.OtherNames.Synonym;
    else
        synonym = "";
    end
    if isfield(species_info.Taxon, 'TaxId')
        ontology_identifier = sprintf("http://purl.obolibrary.org/obo/NCBITaxon_%d", species_info.Taxon.TaxId);
    else
        ontology_identifier = "";
    end
    
    if exist(file_path, 'file')==2
      delete(file_path);
    end
end

