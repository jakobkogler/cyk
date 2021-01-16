# cyk

A context-free grammar parser using the [Cocke–Younger–Kasami algorithm](https://en.wikipedia.org/wiki/CYK_algorithm).

[![Build](https://github.com/jakobkogler/cyk/workflows/build/badge.svg)](https://github.com/jakobkogler/cyk/actions?query=branch%3Amain+workflow%3Abuild)
[![codecov](https://codecov.io/gh/jakobkogler/cyk/branch/main/graph/badge.svg?token=42FEQ64OAG)](https://codecov.io/gh/jakobkogler/cyk)
[![dub](https://img.shields.io/dub/v/cyk)](https://code.dlang.org/packages/cyk)
[![dub](https://img.shields.io/dub/l/cyk)](https://code.dlang.org/packages/cyk)


## Installation

Add `cyk` to your project with

```sh
dub add cyk
```

## Usage

```d
import std.string : split;
import cyk : CYK;

void main() {
    // example parsing a function declaration with arbitrary many parameter
    string[] rules = `
        FunctionDeclaration → ReturnType FunctionName "(" OptionalParameters ")"
        ReturnType → Type
        Type → IntType | FloatingType | "void" | "string"
        IntType → "int" | "long"
        FloatingType → "float" | "double"
        FunctionName → "foo" | "bar" | "baz"
        OptionalParameters → Parameters
        OptionalParameters →
        Parameters → Type ParameterName | Type ParameterName "," Parameters
        ParameterName → "a" | "b" | "c"
    `.split("\n");

    CYK cyk = new CYK(rules, "FunctionDeclaration");

    // check some valid function declarations
    // with the method `bool check(string[])`
    assert(cyk.check("double foo ( )".split));
    assert(cyk.check("string bar ( int a )".split));
    assert(cyk.check("void baz ( int a , float b , long c )".split));

    // check some invalid function declarations
    assert(!cyk.check("double foo ( int )".split));
    assert(!cyk.check("string ( int a )".split));
    assert(!cyk.check("void baz ( int a float b , long c )".split));

    // another simpler example
    string[] rules2 = `
        A → "a"
        B → "b"
        Double → A A | B B
        Different → A B | B A
        Expr → Double ">" Different | Different "<" Double
    `.split("\n");

    CYK cyk2 = new CYK(rules2, "Expr");

    // if all terminals are single chars, you can also use the simpler `bool check(string)` method
    assert(cyk2.check("ab<aa"));
    assert(!cyk2.check("bb<bb"));
}
```
