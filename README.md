[![zig-nightly](https://github.com/notCalle/parzig/workflows/zig-nightly/badge.svg)](https://github.com/notCalle/parzig/actions?query=workflow%3Azig-nightly)
[![zig-v0.8.0](https://github.com/notCalle/parzig/workflows/zig-v0.8.0/badge.svg)](https://github.com/notCalle/parzig/actions?query=workflow%3Azig-v0.8.0)

# ParZig

A parser combinator library for [Zig].

## Install

- Git submodule

  ```shell
  git submodule add https://github.com/notCalle/parzig lib/parzig
  ```

  ```zig
  const parzig = Pkg { .name = "parzig", .path = "lib/parzig/exports.zig" };
  ```

- Import declaration for [`zkg`]

  ```zig
  pub const parzig = zkg.import.git(
      "https://github.com/notCalle/parzig",
      "main",
      null,
  );
  ```

## Examples

- Party Ghosts vs Ghost Parties

  ```zig
  usingnamespace @import("parzig");

  const Ghost = Char('👻');
  const Party = Char('🥳');

  const ghost = "👻";
  const party = "🥳";

  test "ghost party" {
      const GhostParty = Ghost.Seq(Party));
      const ghost_party = ghost ++ party;
      const party_ghost = party ++ ghost;

      std.testing.expectEqualSlices(
          u8,
          ghost_party,
          GhostParty.parse(ghost_party).value().?,
      );

      std.testing.expect(.None == GhostParty.parse(party_ghost));
  }
  ```

- Numeric expression evaluator

  ```zig
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

  // ...

  test "" {
      std.testing.expectEqual(
          Result(i32).some(7, ""),
          Expression.parse("-(1-2)*3+4"),
      );
  }
  ```

[Zig]: https://ziglang.org
[`zkg`]: https://github.com/mattnite/zkg
