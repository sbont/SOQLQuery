/**
 * Created by StevenBontenbal on 06/01/2021.
 */

public class FieldExpression extends ConditionExpression implements RequiresOperator {
    private SelectField field;
    private String opr;
    private Object value;
    private SOQLQueryBuilder queryBuilder;

    public FieldExpression(SelectField field, SOQLQueryBuilder queryBuilder) {
        this.field = field;
        this.queryBuilder = queryBuilder;
    }

    public override String build() {
        return field.toString() + ' ' + opr + ' ' + writeValue(this.value, getSoapType());
    }

    private SoapType getSoapType() {
        return this.field.getSObjectField().getDescribe().getSoapType();
    }

    public SOQLQueryBuilder equals(Object value) {
        this.opr = Operator.EQUALS;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder notEquals(Object value) {
        this.opr = Operator.NOT_EQUALS;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder lessThan(Object value) {
        this.opr = Operator.LESS_THAN;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder greaterThan(Object value) {
        this.opr = Operator.GREATER_THAN;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder equalsOrLess(Object value) {
        this.opr = Operator.LESS_OR_EQUAL;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder equalsOrMore(Object value) {
        this.opr = Operator.GREATER_OR_EQUAL;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder isLike(Object value) {
        this.opr = Operator.LIKE_X;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder isIn(Object value) {
        validateCollection(value);
        this.opr = Operator.IN_X;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder isNotIn(Object value) {
        validateCollection(value);
        this.opr = Operator.NOT_IN_X;
        this.value = value;
        return queryBuilder;
    }
    public SOQLQueryBuilder includes(Object value) {
        validateCollection(value);
        this.opr = Operator.INCLUDES;
        if(value instanceof String) {
            this.value = new Set<String>{(String) value};
        } else {
            this.value = value;
        }
        return queryBuilder;
    }
    public SOQLQueryBuilder excludes(Object value) {
        validateCollection(value);
        this.opr = Operator.EXCLUDES;
        if(value instanceof String) {
            this.value = new Set<String>{(String) value};
        } else {
            this.value = value;
        }
        return queryBuilder;
    }

    private String writeValue(Object value, SoapType targetType) {
        if(value == null) {
            return 'null';
        }
        if(value instanceof Integer || value instanceof Decimal || value instanceof Double) {
            return String.valueOf(value);
            // Warning: instanceof horror ahead
        } else if(value instanceof Date) {
            if(targetType == SoapType.DATE) {
                return Datetime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
            } else {
                return Datetime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0)).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            }
        } else if(value instanceof Datetime) {
            return ((Datetime) value).formatGmt('yyyy-dd-MM\'T\'HH:mm:ss\'Z\'');
        } else if(value instanceof Set<String>) {
            List<String> values = new List<String>();
            for(String o : (Set<String>) value) {
                values.add( writeValue( o, targetType ) );
            }
            return '(' + String.join(values, ', ') + ')';
        } else if(value instanceof List<String>) {
            List<String> values = new List<String>();
            for(String o : (List<String>) value) {
                values.add( writeValue( o, targetType ) );
            }
            return '(' + String.join(values, ', ') + ')';
        } else if(value instanceof Set<Id>) {
            List<String> values = new List<String>();
            for(String o : (Set<Id>) value) {
                values.add( writeValue( o, targetType ) );
            }
            return '(' + String.join(values, ', ') + ')';
        } else if(value instanceof SOQLQueryBuilder) {
            SOQLQueryBuilder subquery = (SOQLQueryBuilder) value;
            return subquery.toString();
        } else {
            return '\'' + String.valueOf(value) + '\'';
        }
    }

    private void validateCollection(Object collection) {
        if(collection instanceof Set<String>) {
            if(((Set<String>) collection).isEmpty()) {
                throwEmptyCollectionException();
            }
        } else if(collection instanceof Set<Id>) {
            if(((Set<Id>) collection).isEmpty()) {
                throwEmptyCollectionException();
            }
        } else if(collection instanceof List<Object>) {
            if(((List<Object>) collection).isEmpty()) {
                throwEmptyCollectionException();
            }
        }
    }

    private void throwEmptyCollectionException() {
        throw new SOQLQueryBuilderException('Empty collection provided for filter on field ' + field.toString());
    }

}