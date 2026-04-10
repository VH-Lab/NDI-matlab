prism2csv <- function(inputSource, outputDir = NULL, overwrite = TRUE) {
  # 1. Load the required library
  if (!requireNamespace("prism2R", quietly = TRUE)) {
    stop("Package 'prism2R' is needed. Please install it.")
  }
  library(prism2R)
  
  # 2. Initialize an empty vector to store all files to be processed
  all_prism_files <- c()

  # 3. Expand inputSource (handles single string or a list/vector)
  for (item in inputSource) {
    if (file.exists(item)) {
      if (file.info(item)$isdir) {
        # If directory, find all .prism files inside
        found_files <- list.files(path = item, 
                                  pattern = "\\.prism$", 
                                  full.names = TRUE, 
                                  recursive = TRUE)
        all_prism_files <- c(all_prism_files, found_files)
      } else {
        # If it's a file, just add it (if it's a .prism file)
        if (grepl("\\.prism$", item, ignore.case = TRUE)) {
          all_prism_files <- c(all_prism_files, item)
        }
      }
    } else {
      warning(paste("Path does not exist and will be skipped:", item))
    }
  }
  
  # Remove duplicates (in case a file is listed twice or inside a listed folder)
  all_prism_files <- unique(all_prism_files)

  if (length(all_prism_files) == 0) {
    message("No .prism files found in the provided inputSource.")
    return(NULL)
  }

  # 4. Process the files
  for (file_path in all_prism_files) {
    # Determine the save location
    if (is.null(outputDir)) {
      current_output_path <- dirname(file_path)
    } else {
      current_output_path <- outputDir
      if (!dir.exists(current_output_path)) {
        dir.create(current_output_path, recursive = TRUE)
      }
    }

    raw_file_name <- tools::file_path_sans_ext(basename(file_path))
    
    # Clean the file name
    clean_file_name <- gsub("[^[:alnum:]]", "_", raw_file_name)
    clean_file_name <- gsub("__+", "_", clean_file_name) 
    
    try({
      current_prism_data <- read_prism(file_path)
      table_names <- names(current_prism_data)
      
      for (t_name in table_names) {
        clean_t_name <- gsub("[^[:alnum:]]", "_", t_name)
        clean_t_name <- gsub("__+", "_", clean_t_name)
        
        export_name <- paste0(clean_file_name, "_", clean_t_name, ".csv")
        export_path <- file.path(current_output_path, export_name)
        
        if (!overwrite && file.exists(export_path)) {
          cat("Skipped (Already exists): ", export_name, "\n")
          next # Skip to the next table
        }

        df_to_save <- current_prism_data[[t_name]]
        write.csv(df_to_save, file = export_path, row.names = FALSE)
        
        cat("Exported: ", export_name, " to ", current_output_path, "\n")
      }
    }, silent = FALSE)
  }
  
  cat("--- Processing Complete! ---\n")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
    # Convert the 3rd argument string ("TRUE"/"FALSE") to a logical value
    ovr <- if(length(args) > 2) as.logical(args[3]) else TRUE
    
    prism2csv(inputSource = args[1], 
              outputDir = if(args[2] == "NULL" || args[2] == "") NULL else args[2], 
              overwrite = ovr)
}