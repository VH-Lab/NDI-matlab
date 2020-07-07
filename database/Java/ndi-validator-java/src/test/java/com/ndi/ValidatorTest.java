package com.ndi;

import org.everit.json.schema.FormatValidator;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ValidatorTest {

    @Test
    void getReportMultipleError() {
        String schema = "{\n" +
                "  \"$schema\": \"http://json-schema.org/schema#\",\n" +
                "  \"id\" : \"my_example_validator\",\n" +
                "  \"title\": \"Student information\",\n" +
                "  \"type\" : \"object\",\n" +
                "  \"properties\" : {\n" +
                "    \"name\" : {\n" +
                "      \"type\": \"string\"\n" +
                "    },\n" +
                "    \"ID\" : {\n" +
                "      \"type\" : \"string\",\n" +
                "      \"format\" : \"date-time\"\n" +
                "    },\n" +
                "    \"Grade\" : {\n" +
                "      \"type\" : \"string\"\n" +
                "    }\n" +
                "  }\n" +
                "}";
        String json = "{\n  \"name\": \"Joe\",\n  \"ID\" : 39,\n  \"Grade\" : 3,\n  \"Friend\" : {\"name\" :  \"Tom\", \"favourite-number\" :  \"8\"}\n}";
        Validator test = new Validator(json, schema, true);
        assertEquals(2, test.getReport().size());
    }

    @Test
    void getReportOneError() {
        String schema = "{\n" +
                "  \"$schema\": \"http://json-schema.org/schema#\",\n" +
                "  \"id\" : \"my_example_validator\",\n" +
                "  \"title\": \"Student information\",\n" +
                "  \"type\" : \"object\",\n" +
                "  \"properties\" : {\n" +
                "    \"name\" : {\n" +
                "      \"type\": \"string\"\n" +
                "    },\n" +
                "    \"ID\" : {\n" +
                "      \"type\" : \"integer\"\n" +
                "    },\n" +
                "    \"Grade\" : {\n" +
                "      \"type\" : \"string\"\n" +
                "    }\n" +
                "  }\n" +
                "}";
        String json = "{\n" +
                "  \"name\": \"Joe\",\n" +
                "  \"ID\" : \"39\",\n" +
                "  \"Grade\" : \"A\"\n" +
                "}";
        Validator test = new Validator(json, schema, true);
        assertEquals(1, test.getReport().size());
    }

    @Test
    void testCustomizedTag() throws IOException {
        TableReader tr = new TableReader(new String[]{"\t","\t","\t"});
        tr.loadData("src/main/resources/GenBankControlledVocabulary.tsv", "Scientific_Name", new ArrayList<>(Arrays.asList("Synonyms", "Other_Common_Name")));
        Table tb = tr.getTable();
        tb.getEntry("Scientific_Name", "Acanthodactylus erythrurus atlanticus");
        Map<String, List<String>> rules = new HashMap<>();
        rules.put("correct", Collections.singletonList("Scientific_Name"));
        FormatValidator fv = new AdvancedEnumFormatValidator("animal_subject", tb, rules);
        String schema = "{\n" +
                "  \"$schema\": \"http://json-schema.org/schema#\",\n" +
                "  \"id\" : \"my_example_validator\",\n" +
                "  \"title\": \"Student information\",\n" +
                "  \"type\" : \"object\",\n" +
                "  \"properties\" : {\n" +
                "    \"name\" : {\n" +
                "      \"type\": \"string\"\n" +
                "    },\n" +
                "    \"ID\" : {\n" +
                "      \"type\" : \"string\",\n" +
                "      \"format\" : \"animal_subject\"\n" +
                "    },\n" +
                "    \"Grade\" : {\n" +
                "      \"type\" : \"string\"\n" +
                "    }\n" +
                "  }\n" +
                "}";
        String json = "{\n  \"name\": \"Joe\",\n  \"ID\" : \"Acanthodactylus erythrurus atlanticus\",\n  \"Grade\" : \"A\",\n  \"Friend\" : {\"name\" :  \"Tom\", \"favourite-number\" :  \"8\"}\n}";
        Validator test = new Validator(json, schema, true, Collections.singletonList(fv));
        assertEquals(0, test.getReport().size());
    }
}