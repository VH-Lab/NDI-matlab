package com.ndi;

import org.json.JSONObject;
import org.json.JSONTokener;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;

/**
 * An interface for all objects that is capable of validating a JSON Instance against
 * a JSON Schema. This is created in case that we want to switch to a different open-source
 * JSON Validator implementation. All we need is to implement this interface and implement
 * performValidation method as well as the getReport method.
 */
public interface Validatable {

    /**
     * Acquire an report of validation.
     *
     * @return a key-value pairs, where the key represents the
     *         JSON key that has the wrong type, and the value represents
     *         a string detailing the error message. If the HashMap is empty,
     *         then it means the json document is valid (exactly what performValidation()
     *         returns)
     */
    HashMap<String, String> getReport();

    class Util {
        /**
         * A helper method that can used to read a JSON File from an absolute path, and
         * then convert it into an instance of JSONObject
         * @param filePath  the absolute path to the JSON file
         * @return  an instance of JSONObject
         * @throws IOException  when file path is invalid or any error occured while
         * reading the file
         */
        public static JSONObject readJSONFile(String filePath) throws IOException {
            JSONObject output;
            try(InputStream is = new FileInputStream(filePath)){
                output = new JSONObject(new JSONTokener(is));
            }
            return output;
        }
    }
}

