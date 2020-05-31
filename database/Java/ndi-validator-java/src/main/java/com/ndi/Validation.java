package com.ndi;

import org.json.JSONObject;
import java.util.HashMap;

public interface Validation {
    public HashMap<String, String>
        performValidation(JSONObject input, JSONObject schema);
}

