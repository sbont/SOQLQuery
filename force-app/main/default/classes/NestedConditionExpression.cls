public class NestedConditionExpression extends ConditionExpression {
    List<ConditionExpression> conditionExpressions;
    String logicalOptr;

    public NestedConditionExpression(List<ConditionExpression> conditionExpressions, String logicalOptr) {
        if(logicalOptr == LogicalOperator.NOT_X && conditionExpressions.size() != 1) {
            throw new QueryBuilderException('A \'NOT\' expression cannot have more than one condition.');
        }
        this.conditionExpressions = conditionExpressions;
        this.logicalOptr = logicalOptr;
    }

    public void add(ConditionExpression conditionExpression) {
        if(logicalOptr == LogicalOperator.NOT_X) {
            throw new QueryBuilderException('A \'NOT\' expression cannot have more than one condition.');
        }
        conditionExpressions.add(conditionExpression);
    }

    public Boolean isNegative() {
        return logicalOptr == LogicalOperator.NOT_X;
    }

    public override String build() {
        List<String> parts = new List<String>();
        for(ConditionExpression conditionExpression : conditionExpressions) {
            if(conditionExpression instanceof NestedConditionExpression) {
                parts.add('( ' + conditionExpression.build() + ' )');
            } else {
                parts.add(conditionExpression.build());
            }
        }
        if(logicalOptr == LogicalOperator.NOT_X) {
            return logicalOptr + ' ' + parts[0];
        } else {
            return String.join(parts, ' ' + logicalOptr + ' ');
        }
    }

    public List<ConditionExpression> getConditionExpressions() {
        return this.conditionExpressions;
    }
}