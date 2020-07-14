

mypostgresdb = ndi_postgresdb( % insert your creator arguments here ); % here it connects to your postgres database

   % json, you can say matlab_struct = jsondecode(json_info); mydoc = ndi_document(matlab_struct);

doc = mypostgresdb.search( ndi_query('list','exact_string','abc','') );

  % show that mydocs has the right value
 
