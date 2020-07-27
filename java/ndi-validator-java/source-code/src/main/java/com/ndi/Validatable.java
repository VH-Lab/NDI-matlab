package com.ndi;

import org.json.JSONObject;
import org.json.JSONTokener;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;

/**
 * An interface for all objects capable of validating a JSON Instance against
 * a JSON Schema. This is created in case that we want to switch to a different open-source
 * JSON Validator implementation. All we need is to implement this interface and implement
 * the getReport method.
 */
public interface Validatable {

    /**
     * Acquire a report of validation.
     *
     * @return a key-value pairs, where the keys are the JSON key that has the wrong type,
     *         and the value are strings detailing the error messages. If the HashMap
     *         is empty, then it means the json document is valid
     */
    HashMap<String, String> getReport();

    /**
     * An inner class that contains methods all the subclasses that implement this interface
     * might use. This is created so that we do not need to make Validatable an abstract class,
     * which prevents the fragile base class problem
     */
    class Util {
        /**
         * A helper method that can be used to read a JSON File from an absolute path, and
         * then convert it into an instance of JSONObject
         * @param filePath  the absolute path to the JSON file
         * @return  an instance of JSONObject
         * @throws IOException  when the file path is invalid or any IO error has occurred while
         * reading the file
         */
        public static JSONObject readJSONFile(String filePath) throws IOException {
            JSONObject output;
            try(InputStream is = new FileInputStream(filePath)){
                output = new JSONObject(new JSONTokener(is));
            }
            return output;
        }

        /**
         * This class should only consist of static method (no instance method allowed)
         */
        private Util(){};
    }
}

