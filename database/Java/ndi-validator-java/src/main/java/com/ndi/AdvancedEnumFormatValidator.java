package com.ndi;

import org.everit.json.schema.FormatValidator;

import java.util.Optional;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;

/**
 * A very flexible customized format option validator. It allows user to creates
 * format tag that is not present in the Json Schema Official Specification. This validator
 * can be used when we want to restrict an entry to a set of predefined values, but at the same
 * time, when the user has entered another set of value, we want to create suggestions for the user
 * to enter the correct values. It extends the FormatValidator class, which is called by the Everit
 * Validator when it encounters the this user's defined format tag in the schema document
 */
public class AdvancedEnumFormatValidator implements FormatValidator {
    private final String formatName;
    private final Table table;
    private final Map<String, List<String>> rules;

    /**
     * Constructor for the AdvancedEnumFormatValidator class. It takes the following arguments
     *
     * @param formatName    The name of our customized format tag
     *
     * @param table         An instance of com.ndi.Table object including predefined values
     *                      that we want to restrict our entries to
     *
     * @param rules         The validation rules: it should be an instance of HashMap. It should contains
     *                      at least one keys: 1) "correct", 2) suggestions (which is optional), whose values
     *                      need to be an instance of java.util.List. The value of the key "correct" consist of
     *                      a list of accepted columns (that is if the user enter an entry that belongs to a entries
     *                      in one of the columns, we accept the user's entry), otherwise if the user has entered an
     *                      entries in the list of "suggestions" value's column, then the error message will provide
     *                      hint that allows user to enter the value in the corrected column
     */
    public AdvancedEnumFormatValidator(String formatName, Table table, Map<String, List<String>> rules){
        if (table == null) {
            throw new IllegalArgumentException("you must provide an instance of Table");
        }
        if (!rules.containsKey("correct")){
            throw new IllegalArgumentException("Rules must contain a key named correct to specify the column we want" +
                    "the string to be one of its entries");
        }
        for (String correctColumn : rules.get("correct")){
            if (!table.isColKey(correctColumn)){
                throw new IllegalArgumentException("Correct columns must come from a real column from the provided table");
            }
        }
        if (rules.containsKey("suggestions")){
            for (String suggestion : rules.get("suggestions")){
                if (!table.isColKey(suggestion)){
                    throw new IllegalArgumentException("Columns that lead to error messages with suggestions must come" +
                            "from one of the columns in the provided table");
                }
            }
        }
        this.formatName = formatName;
        this.table = table;
        this.rules = rules;
    }

    /**
     * Perform the validation step
     *
     * @param subject   the user input in that json entry
     * @return          List of error messages. The List would be empty if the user's entry
     *                  is valid.
     */
    @Override
    public Optional<String> validate(String subject) {
        List<String> correctOptions = new ArrayList<>();
        for (String correctColumn : rules.get("correct")) {
            try {
                this.table.getEntry(correctColumn, "subject");
                return Optional.empty();
            }
            catch (IllegalArgumentException ignored) {}
        }
        if (this.rules.containsKey("suggestions")) {
            for (String suggestion : this.rules.get("suggestions")) {
                try{
                    this.table.getEntry(suggestion, subject, suggestion);
                    for (String correctColumn : this.rules.get("correct")){
                        correctOptions.addAll(this.table.getEntry(correctColumn, subject, suggestion));
                    }
                    return Optional.of("Entered: " + subject + ". Expected: the following" + correctOptions);
                }
                catch (IllegalArgumentException ignored){}
            }
        }
        return Optional.of("Entered: " + subject + ". Expected: an entry from the columns " + rules.get("correct"));
    }

    /**
     * The name of the user-defined format tag
     *
     * @return  the name of this format tag
     */
    @Override
    public String formatName() {
        return this.formatName;
    }
}
