
import gwr/text/sexpr
import gleeunit
import gleeunit/should

pub fn main()
{
    gleeunit.main()
}

pub fn parse_sexpr_1_test()
{
    sexpr.parse("(cat dog)")
    |> should.be_ok
    |> should.equal([sexpr.Expression([sexpr.Atom("cat"), sexpr.Atom("dog")])])
}

pub fn parse_sexpr_2_test()
{
    sexpr.parse("(cat(dog parrot))")
    |> should.be_ok
    |> should.equal([sexpr.Expression([sexpr.Atom("cat"), sexpr.Expression([sexpr.Atom("dog"), sexpr.Atom("parrot")])])])
}