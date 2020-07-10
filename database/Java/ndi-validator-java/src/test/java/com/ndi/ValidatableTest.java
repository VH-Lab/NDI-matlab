package com.ndi;

import org.everit.json.schema.FormatValidator;
import org.junit.jupiter.api.Test;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ValidatableTest {

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
        Validatable test = new Validator(json, schema);
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
        Validatable test = new Validator(json, schema);
        assertEquals(1, test.getReport().size());
    }

    @Test
    void testCustomizedTag() throws IOException {
        FormatValidator fv = new EnumFormatValidator.Builder()
                .setFormatTag("animal_subject")
                .setParserFormat(new TableFormat().addFormat(new String[]{"\t", "\t", "\t"}))
                .setFilePath("src/main/resources/GenBankControlledVocabulary.tsv.gz")
                .setRules(new Rules().addExpectedColumn("Scientific_Name"))
                .loadDataGzip()
                .build();
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
        Validatable test = new Validator(json, schema).addValidator(fv);
        assertEquals(0, test.getReport().size());
    }
}