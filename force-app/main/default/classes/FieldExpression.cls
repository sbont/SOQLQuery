public class FieldExpression extends ConditionExpression {

    private SelectField field;
    private String operator;
    private Object value;

    public FieldExpression(SelectField field, String operator, Object value) {
        this.field = field;
        this.operator = operator;
        this.value = value;
    }

    public override String build() {
        return field.toString() + ' ' + operator + ' ' + writeValue();
    }

    private String writeValue() {
        if(value instanceof Date || value instanceof Datetime || value instanceof Integer || value instanceof Decimal || value instanceof Double) {
            return String.valueOf(value);
        } else {
            return '\'' + String.valueOf(value) + '\'';
        }
    }
}