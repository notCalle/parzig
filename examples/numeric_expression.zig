const std = @import("std");
usingnamespace @import("parzig");

const Expression = Parser(struct {
    pub fn parse(input: Input) Result(i32) {
        return Term.Opt(AddSub.Seq(Term)).Map(evalExpression);
    }
});

const Term = Parser(struct {
    pub fn parse(input: Input) Result(i32) {
        return Factor.Opt(MulDiv.Seq(Factor)).Map(evalTerm);
    }
});

const Factor = Parser(struct {
    pub fn parse(input: Input) Result(i32) {
        return Opt(Char('-')).Seq(Number.Or(Paren)).Map(evalFactor);
    }
});

const Number = Parser(struct {
    pub fn parse(input: Input) Result(i32) {
        return CharRange('0', '9').Many1.Map(evalNumber);
    }
});

const Paren = Parser(struct {
    pub fn parse(input: Input) Result(i32) {
        return Char('(').Seq(Expression).Seq(Char(')')).Map(evalParen);
    }
});

// TODO: Implement the rest ...

test "" {
    std.testing.expectEqual(
        Result(i32).some(7, ""),
        Expression.parse("-(1-2)*3+4"),
    );
}
