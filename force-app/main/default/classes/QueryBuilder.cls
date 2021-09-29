public with sharing class QueryBuilder implements SelectItem, AcceptsFilter {

    private SObjectType targetObject;
    private ChildRelationship targetRelationship;
    private List<SelectItem> selectItems;
    private String whereClause;
    private ConditionExpression whereConditionExpression;
    private Boolean withSecurityEnforced;
    private List<SortOrder> sortOrders;
    private Integer maxRows;

    public QueryBuilder(SObjectType sObjectType) {
        this.targetObject = sObjectType;
        selectItems = new List<SelectItem>();
        sortOrders = new List<SortOrder>();
    }

    private QueryBuilder(ChildRelationship childRelationship) {
        this.targetRelationship = childRelationship;
        this.targetObject = childRelationship.childSObject;
        selectItems = new List<SelectItem>();
        sortOrders = new List<SortOrder>();
    }

    public QueryBuilder subquery(QueryBuilder subquery) {
        selectItems.add(subquery);
        return this;
    }

    public QueryBuilder getSubquery(String relationshipName) {
        for(ChildRelationship relationship : targetObject.getDescribe().getChildRelationships()) {
            if(relationship.getRelationshipName() == relationshipName) {
                return new QueryBuilder(relationship);
            }
        }
        throw new QueryBuilderException('No relationship found with name ' + relationshipName);
    }

    public String soql() {
        String[] queryParts = new List<String>();
        queryParts.add('SELECT ' + String.join(getSelectItemParts(), ', '));
        queryParts.add('FROM ' + getTarget());
        if(whereClause != null) {
            queryParts.add('WHERE ' + whereClause);
        } else if(whereConditionExpression != null) {
            queryParts.add('WHERE ' + whereConditionExpression.build());
        }
        if(withSecurityEnforced != null && withSecurityEnforced) {
            queryParts.add('WITH SECURITY_ENFORCED');
        }
        if(sortOrders.size() > 0) {
            queryParts.add('ORDER BY ' + String.join( getSortOrderParts(), ', '));
        }
        if(maxRows != null) {
            queryParts.add('LIMIT ' + maxRows);
        }
        System.debug(String.join(queryParts, ' '));
        return String.join(queryParts, ' ');
    }

    public List<SObject> query() {
        return Database.query( soql() );
    }

    public SObject first() {
        List<SObject> results = query();
        if(results.size() > 0) {
            return results[0];
        } else {
            return null;
        }
    }

    public override String toString() {
        return '(' + soql() + ')';
    }

    public QueryBuilder fields(List<SObjectField> fields) {
        for(SObjectField field : fields) {
            field(field);
        }
        return this;
    }

    public QueryBuilder fieldToLabel(SObjectField field) {
        if(field == null) {
            throw new QueryBuilderException('Provided SObjectField cannot be null.');
        }
        SelectField selectField = new SelectField(field);
        selectField.setToLabel();
        addSelectField(selectField);
        return this;
    }

    public QueryBuilder field(SObjectField field) {
        if(field == null) {
            throw new QueryBuilderException('Provided SObjectField cannot be null.');
        }
        SelectField selectField = new SelectField(field);
        addSelectField(selectField);
        return this;
    }

    public QueryBuilder relatedFields(SObjectField relationshipField, List<SObjectField> targetFields) {
        for(SObjectField targetField : targetFields) {
            relatedField(relationshipField, targetField);
        }
        return this;
    }

    public QueryBuilder relatedField(SObjectField relationshipField, SObjectField targetField) {
        return relatedField(new List<SObjectField>{relationshipField, targetField});
    }

    public QueryBuilder relatedField(List<SObjectField> fieldPath) {
        SelectField selectField = new SelectField(fieldPath[0]);
        for(Integer i = 1; i < fieldPath.size(); i++) {
            SObjectField sObjectField = fieldPath[i];
            selectField.pointToRelatedField(sObjectField);
        }
        addSelectField(selectField);
        return this;
    }

    public QueryBuilder fieldSet(String fieldSetName) {
        FieldSet fieldSet = targetObject.getDescribe().FieldSets.getMap().get(fieldSetName);
        if(fieldSet == null) throw new QueryBuilderException('Field Set not found with name ' + fieldSetName + '.');
        fieldSet(fieldSet);
        return this;
    }

    public QueryBuilder fieldSet(FieldSet fieldSet) {
        for(FieldSetMember fieldSetMember : fieldSet.getFields()) {
            field(fieldSetMember.getSObjectField());
        }
        return this;
    }

    public QueryBuilder relatedFieldSet(SObjectField relationshipField, String fieldSetName) {
        SObjectType targetObjectType = relationshipField.getDescribe().getReferenceTo()[0];
        FieldSet fieldSet = targetObjectType.getDescribe().FieldSets.getMap().get(fieldSetName);
        if(fieldSet == null) throw new QueryBuilderException('Field Set not found on object ' + targetObjectType + ' with name ' + fieldSetName + '.');
        relatedFieldSet(relationshipField, fieldSet);
        return this;
    }

    public QueryBuilder relatedFieldSet(SObjectField relationshipField, FieldSet fieldSet) {
        for(FieldSetMember fieldSetMember : fieldSet.getFields()) {
            relatedField(new List<SObjectField>{relationshipField, fieldSetMember.getSObjectField()});
        }
        return this;
    }

    public QueryBuilder whereClause(String whereClause) {
        if(whereConditionExpression != null) throw new QueryBuilderException('Use either a String as WHERE clause, or an expression. You cannot use both at the same time.');
        this.whereClause = whereClause;
        return this;
    }

    public RequiresOperator filter(SObjectField field) {
        return filter(new List<SObjectField>{field});
    }

    public RequiresOperator filter(List<SObjectField> fieldPath) {
        if(whereClause != null) throw new QueryBuilderException('Use either a String as WHERE clause, or an expression. You cannot use both at the same time.');
        SelectField selectField = SelectField.createFromFieldPath(fieldPath);
        ConditionExpression newExpression = new FieldExpression(selectField, this);
        if(whereConditionExpression != null) {
            if(whereConditionExpression instanceof NestedConditionExpression
                    && ((NestedConditionExpression) whereConditionExpression).isNegative() == false) {
                ((NestedConditionExpression) whereConditionExpression).add(newExpression);
            } else {
                ConditionExpression existingExpression = whereConditionExpression;
                whereConditionExpression = new NestedConditionExpression(new ConditionExpression[]{existingExpression, newExpression}, LogicalOperator.AND_X);
            }
        } else {
            whereConditionExpression = newExpression;
        }
        return (RequiresOperator) newExpression;
    }

    public QueryBuilder filterLogic(String logic) {
        this.whereConditionExpression = parseToken(logic);
        return this;
    }

    private NestedConditionExpression parseToken(String token) {
        List<ConditionExpression> subExpressions = new List<ConditionExpression>(); // Contains the different parts of the expression
        String operator; // AND or OR
        Integer subExpressionStart; // Position after the opening parenthesis
        Integer depth = 0; // Sub-expression depth
        Boolean currentlyInMixedAndExpression = false; // If we are currently expecting the right-hand side of an AND operator while in a mixed AND & OR expression
        List<ConditionExpression> andExpressionsInMixedLogic = new List<ConditionExpression>(); // If we have AND's and OR's in one expression without parentheses, we collect the AND's to regard them as a parenthesised sub-expression
        for(Integer pos = 0; pos < token.length(); pos ++) {
            String chr = token.mid(pos, 1);
            if(chr == '(') {
                if(depth == 0) {
                    subExpressionStart = pos + 1;
                }
                depth ++;
            }
            if(chr == ')') {
                depth--;
                if (depth == 0) {
                    NestedConditionExpression subExpression = parseToken( token.substring(subExpressionStart, pos) );
                    subExpressions.add(subExpression);
                    subExpressionStart = null;
                }
            }
            if(depth == 0) {
                if(chr.isNumeric()) {
                    if(subExpressionStart == null) {
                        subExpressionStart = pos;
                    }
                    String nextChar = token.mid(pos + 1, 1);
                    if(!nextChar.isNumeric()) {
                        String indexValue = token.substring(subExpressionStart, pos + 1);
                        Integer index = Integer.valueOf(indexValue);
                        subExpressionStart = null;
                        ConditionExpression referencedExpression = ((NestedConditionExpression) whereConditionExpression).getConditionExpressions()[index - 1];
                        if(currentlyInMixedAndExpression) {
                            andExpressionsInMixedLogic.add(referencedExpression);
                        } else {
                            subExpressions.add(referencedExpression);
                        }
                    }
                }
                if(chr == 'A' && token.mid(pos, 3) == 'AND') {
                    if(operator == LogicalOperator.OR_X) {
                        currentlyInMixedAndExpression = true;
                        ConditionExpression previousExpression = subExpressions.remove( subExpressions.size() - 1 );
                        andExpressionsInMixedLogic.add(previousExpression);
                    } else {
                        operator = LogicalOperator.AND_X;
                    }
                    pos += 2;
                }
                if(chr == 'O' && token.mid(pos, 2) == 'OR') {
                    if(operator == LogicalOperator.AND_X) {
                        ConditionExpression andExpression = new NestedConditionExpression(new List<ConditionExpression>(subExpressions), LogicalOperator.AND_X);
                        subExpressions = new List<ConditionExpression>{andExpression};
                    }
                    if(currentlyInMixedAndExpression) {
                        ConditionExpression andExpression = new NestedConditionExpression(new List<ConditionExpression>(andExpressionsInMixedLogic), LogicalOperator.AND_X);
                        subExpressions.add(andExpression);
                        andExpressionsInMixedLogic = new List<ConditionExpression>();
                        currentlyInMixedAndExpression = false;
                    }
                    operator = LogicalOperator.OR_X;
                    pos += 1;
                }
            }
        }
        if(currentlyInMixedAndExpression) {
            ConditionExpression andExpression = new NestedConditionExpression(new List<ConditionExpression>(andExpressionsInMixedLogic), LogicalOperator.AND_X);
            subExpressions.add(andExpression);
        }
        return new NestedConditionExpression(subExpressions, operator);
    }

    public QueryBuilder orderBy(SObjectField field) {
        SortOrder sortOrder = new SortOrder(field, this);
        sortOrders.add(sortOrder);
        return this;
    }

    public QueryBuilder ascending() {
        SortOrder last = sortOrders.get(sortOrders.size() - 1);
        last.ascending();
        return this;
    }

    public QueryBuilder descending() {
        SortOrder last = sortOrders.get(sortOrders.size() - 1);
        last.descending();
        return this;
    }

    public QueryBuilder nullsFirst() {
        SortOrder last = sortOrders.get(sortOrders.size() - 1);
        last.nullsFirst();
        return this;
    }

    public QueryBuilder nullsLast() {
        SortOrder last = sortOrders.get(sortOrders.size() - 1);
        last.nullsLast();
        return this;
    }

    public QueryBuilder withSecurityEnforced() {
        this.withSecurityEnforced = true;
        return this;
    }

    public QueryBuilder setLimit(Integer maxRows) {
        this.maxRows = maxRows;
        return this;
    }

    private void addSelectField(SelectField selectField) {
        if(!selectItems.contains(selectField)) {
            selectItems.add(selectField);
            /*SObjectField field = selectField.getSObjectField();
            if(field.getDescribe().getReferenceTo().size() > 0) {
                // The related field itself is a lookup, we add the Looked_Up_Object.Name field as well
                SObjectType targetObjectType = field.getDescribe().getReferenceTo()[0];
                SObjectField relatedNameField = targetObjectType.getDescribe().fields.getMap().get('Name');
                if(relatedNameField != null) {
                    SelectField selectNameField = selectField.copy().pointToRelatedField(relatedNameField);
                    if(!selectItems.contains(selectNameField)) {
                        selectItems.add(selectNameField);
                    }
                }
            }*/
        }
    }

    private List<String> getSelectItemParts() {
        List<String> fieldNames = new List<String>();
        for(SelectItem item : selectItems) {
            fieldNames.add(item.toString());
        }
        return fieldNames;
    }

    private List<String> getSortOrderParts() {
        List<String> fieldOrderByList = new List<String>();
        for(SortOrder sortOrder : sortOrders) {
            fieldOrderByList.add(sortOrder.build());
        }
        return fieldOrderByList;
    }

    private String getTarget() {
        return targetRelationship != null ? targetRelationship.getRelationshipName() : String.valueOf(targetObject);
    }

    public Boolean equals(Object other) {
        if(other instanceof QueryBuilder) {
            QueryBuilder otherQuery = (QueryBuilder) other;
            return this.soql() == otherQuery.soql();
        } else {
            return false;
        }
    }

    public Integer hashCode() {
        return 31 * String.valueOf(this.soql()).hashCode();
    }

}