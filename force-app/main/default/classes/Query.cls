public with sharing class Query implements QueryItem {

    private List<QueryItem> queryItems;
    private SObjectType targetObject;
    private ChildRelationship targetRelationship;
    private String whereClause;
    private ConditionExpression whereConditionExpression;
    private Boolean withSecurityEnforced;
    private Integer maxRows;

    public Query(SObjectType targetObject) {
        this.targetObject = targetObject;
        queryItems = new List<QueryItem>();
    }

    private Query(ChildRelationship childRelationship) {
        this.targetRelationship = childRelationship;
        this.targetObject = childRelationship.getChildSObject();
        queryItems = new List<QueryItem>();
    }

    public Query addSubQuery(ChildRelationship childRelationship) {
        Query subQuery = new Query(childRelationship);
        queryItems.add(subQuery);
        return subQuery;
    }

    public String construct() {
        String[] queryParts = new List<String>();
        queryParts.add('SELECT ' + String.join(getQueryItemParts(), ', '));
        queryParts.add('FROM ' + getTarget());
        if(whereClause != null) {
            queryParts.add('WHERE ' + whereClause);
        } else if(whereConditionExpression != null) {
            queryParts.add('WHERE ' + whereConditionExpression.build());
        }
        if(withSecurityEnforced != null && withSecurityEnforced) {
            queryParts.add('WITH SECURITY_ENFORCED');
        }
        if(maxRows != null) {
            queryParts.add('LIMIT ' + maxRows);
        }
        return String.join(queryParts, ' ');
    }

    public override String toString() {
        return '(' + construct() + ')';
    }

    public void addFields(List<SObjectField> fields) {
        for(SObjectField field : fields) {
            addField(field);
        }
    }

    public void addField(SObjectField field) {
        SelectField selectField = new SelectField(field);
        addSelectField(selectField);
    }

    private void addSelectField(SelectField selectField) {
        if(!queryItems.contains(selectField)) {
            queryItems.add(selectField);

            SObjectField field = selectField.getSObjectField();
            if(field.getDescribe().getReferenceTo().size() > 0) {
                // The related field itself is a relationship, so we add the Looked_Up_Object.Name field as well
                SObjectType targetObjectType = field.getDescribe().getReferenceTo()[0];
                SObjectField relatedNameField = targetObjectType.getDescribe().fields.getMap().get('Name');
                if(relatedNameField != null) {
                    SelectField selectNameField = selectField.copy().pointToRelatedField(relatedNameField);
                    if(!queryItems.contains(selectNameField)) {
                        queryItems.add(selectNameField);
                    }
                }
            }
        }
    }

    public void addField(List<SObjectField> fieldPath) {
        SelectField selectField = new SelectField(fieldPath[0]);
        for(Integer i = 1; i < fieldPath.size(); i++) {
            SObjectField sObjectField = fieldPath[i];
            selectField.pointToRelatedField(sObjectField);
        }
        addSelectField(selectField);
    }

    public void addRelatedFields(SObjectField relationshipField, List<SObjectField> targetFields) {
        for(SObjectField targetField : targetFields) {
            addField(new List<SObjectField>{relationshipField, targetField});
        }
    }

    public void addFieldSet(String fieldSetName) {
        FieldSet fieldSet = targetObject.getDescribe().FieldSets.getMap().get(fieldSetName);
        if(fieldSet == null) {
            throw new SOQLQueryException('Field Set not found with name ' + fieldSetName + '.');
        }
        addFieldSet(fieldSet);
    }

    public void addFieldSet(FieldSet fieldSet) {
        for(FieldSetMember fieldSetMember : fieldSet.getFields()) {
            addField(fieldSetMember.getSObjectField());
        }
    }

    public void addRelatedFieldSet(SObjectField relationshipField, String fieldSetName) {
        SObjectType targetObjectType = relationshipField.getDescribe().getReferenceTo()[0];
        FieldSet fieldSet = targetObjectType.getDescribe().FieldSets.getMap().get(fieldSetName);
        if(fieldSet == null) {
            throw new SOQLQueryException('Field Set not found on object ' + targetObjectType + ' with name ' + fieldSetName + '.');
        }
        addRelatedFieldSet(relationshipField, fieldSet);
    }

    public void addRelatedFieldSet(SObjectField relationshipField, FieldSet fieldSet) {
        for(FieldSetMember fieldSetMember : fieldSet.getFields()) {
            addField(new List<SObjectField>{relationshipField, fieldSetMember.getSObjectField()});
        }
    }

    public void setWhereClause(String whereClause) {
        this.whereClause = whereClause;
    }

    public void addWhereClause(SObjectField field, String operator, Object value) {
        addWhereClause(new List<SObjectField>{field}, operator, value);
    }

    public void addWhereClause(List<SObjectField> fieldPath, String operator, Object value) {
        if(whereClause != null) {
            throw new SOQLQueryException('Use either a String as WHERE clause, or an expression. You cannot use both at the same time.');
        }
        SelectField selectField = SelectField.createFromFieldPath(fieldPath);
        ConditionExpression newExpression = new FieldExpression(selectField, operator, value);
        if(whereConditionExpression != null) {
            if(whereConditionExpression instanceof NestedConditionExpression && ((NestedConditionExpression) whereConditionExpression).isNegative() == false) {
                ((NestedConditionExpression) whereConditionExpression).add(newExpression);
            } else {
                ConditionExpression existingExpression = whereConditionExpression;
                whereConditionExpression = new NestedConditionExpression(new ConditionExpression[]{existingExpression, newExpression}, LogicalOperator.AND_X);
            }
        } else {
            whereConditionExpression = newExpression;
        }
    }

    public void setWithSecurityEnforced() {
        this.withSecurityEnforced = true;
    }

    public void setLimit(Integer maxRows) {
        this.maxRows = maxRows;
    }

    private List<String> getQueryItemParts() {
        List<String> fieldNames = new List<String>();
        for(QueryItem item : queryItems) {
            fieldNames.add(item.toString());
        }
        return fieldNames;
    }

    private String getTarget() {
        return targetRelationship != null ? targetRelationship.getRelationshipName() : String.valueOf(targetObject);
    }

    public Boolean equals(Object other) {
        if(other instanceof Query) {
            Query otherQuery = (Query) other;
            return this.construct() == otherQuery.construct();
        } else {
            return false;
        }
    }

    public Integer hashCode() {
        return 31 * String.valueOf(this.construct()).hashCode();
    }

}