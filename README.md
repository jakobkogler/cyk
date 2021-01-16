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
    string[] rules = [
        `FunctionDeclaration → ReturnType FunctionName "(" OptionalParameters ")"`,
        `ReturnType → Type`,
        `Type → IntType | FloatingType | "void" | "string"`,
        `IntType → "int" | "long"`,
        `FloatingType → "float" | "double"`,
        `FunctionName → "foo" | "bar" | "baz"`,
        `OptionalParameters → Parameters`,
        `OptionalParameters →`,
        `Parameters → Type ParameterName | Type ParameterName "," Parameters`,
        `ParameterName → "a" | "b" | "c"`
    ];

    CYK cyk = new CYK(rules, "FunctionDeclaration");

    // some valid function declarations
    assert(cyk.check("double foo ( )".split));
    assert(cyk.check("string bar ( int a )".split));
    assert(cyk.check("void baz ( int a , float b , long c )".split));

    // some invalid function declarations
    assert(!cyk.check("double foo ( int )".split));
    assert(!cyk.check("string ( int a )".split));
    assert(!cyk.check("void baz ( int a float b , long c )".split));
}
```
